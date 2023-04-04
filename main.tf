# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  access_key = var.accessKey
  secret_key = var.secretKey
}

##### Create VPC ######

resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"
}

# create IG

resource "aws_internet_gateway" "demo_ig" {
  vpc_id = aws_vpc.demo_vpc.id
  tags = var.tags
}

# 3. Create RT

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.demo_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.demo_ig.id
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.demo_ig.id
    }

    tags = var.tags
}

#Compress lamda code to zip file
provider "archive" {}

data "archive_file" "zip_elb" {
    type = "zip"
    source_file = "/Users/phanisurapaneni/Documents/BRP/API_POC/RequestQuoteEvent.py"
    output_path = "/Users/phanisurapaneni/Documents/BRP/API_POC/RequestQuoteEvent.zip"
}

resource "aws_lambda_function" "lambda" {
  function_name = "demo-alb-lambda-test"
  filename         = data.archive_file.zip_elb.output_path
  source_code_hash = data.archive_file.zip_elb.output_base64sha256
  role    = aws_iam_role.lambda_role.arn
  handler = "RequestQuoteEvent.lambda_handler"
  runtime = "python3.9"

  # vpc_config {
  #   subnet_ids         = subnet-1.id
  #   security_group_ids = [aws_security_group.nsg_lambda.id]
  # }

}

resource "aws_lambda_permission" "allow_alb_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_alb_target_group.main.arn
}

data "archive_file" "zip_eb_conn" {
    type = "zip"
    source_file = "/Users/phanisurapaneni/Documents/BRP/API_POC/UpdateEBConnections.py"
    output_path = "/Users/phanisurapaneni/Documents/BRP/API_POC/UpdateEBConnections.zip"
}

# Check "API Gateway" section to see this lambda invokation permission
resource "aws_lambda_function" "lambda_update_eb_conn" {
  function_name = "demo-alb-lambda-eb-connections"
  filename         = data.archive_file.zip_eb_conn.output_path
  source_code_hash = data.archive_file.zip_eb_conn.output_base64sha256
  role    = aws_iam_role.lambda_role_update_eb_conn.arn
  handler = "UpdateEBConnections.lambda_handler"
  runtime = "python3.9"
}

##### Create a Subnets (ALB needs atleast two subnets) ######
resource "aws_subnet" "public-subnet" {
  count = "${length(var.subnet_cidrs_public)}"

  vpc_id = aws_vpc.demo_vpc.id
  cidr_block = "${var.subnet_cidrs_public[count.index]}"
  availability_zone = "${var.availability_zones[count.index]}"

  tags = merge (
    "${var.tags}",
    {
      Name = "public"
    },
  )
}

# Associate Subnets with RT 
resource "aws_route_table_association" "public_rt-association" {
  count = "${length(var.subnet_cidrs_public)}"

  subnet_id      = "${element(aws_subnet.public-subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.public_rt.id}"
}

##### Create ALB and Target Group ######


resource "aws_alb" "demo_alb" {
  name = "test-lb-tf"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.nsg_lb.id]
  subnets = [for subnet in aws_subnet.public-subnet : subnet.id]

  access_logs {
    bucket  = aws_s3_bucket.lb_access_logs.bucket
    # prefix  = "test-lb"
    enabled = true
  }

  tags = "${var.tags}"
}

resource "aws_alb_target_group" "main" {
  name        = "demo-alb-test"
  port        = var.lb_port
  protocol    = var.lb_protocol
  #vpc_id      = aws_vpc.demo_vpc.id -- not required for lambda targets
  target_type = "lambda"

  tags = "${var.tags}"
}

resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_alb_target_group.main.arn
  target_id        = aws_lambda_function.lambda.arn

  depends_on       = [aws_lambda_permission.allow_alb_to_invoke_lambda]
}



# adds an http listener to the load balancer and allows ingress
# (delete this file if you only want https) 

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.demo_alb.id
  port              = var.lb_port
  protocol          = var.lb_protocol

  # default_action {
  #   type = "redirect"

  #   redirect {
  #     port        = "80"
  #     protocol    = "HTTP"
  #     status_code = "HTTP_301"
  #   }
  # }
  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.main.arn
  }
}



data "aws_elb_service_account" "main" {}

# bucket for storing ALB logs
#TODO : Sae the state of S3 and delete
resource "aws_s3_bucket" "lb_access_logs" {
  bucket = "demo-alb-test-bucket-03072023"
  # acl = "private"
  tags = "${var.tags}"
  force_destroy = true
}





# Lambda egress for event bridge
# resource "aws_security_group_rule" "nsg_lambda_egress_rule" {
  # security_group_id = aws_security_group.nsg_lambda.id
  # description = "Only allow SG ${var.app}-${var.environment}-lambda to connect to ${var.app}-${var.environment}-eb on port ${var.lb_port}"
  # type = "egress"
  # from_port = var.lb_port
  # to_port = var.lb_port
  # protocol = "tcp"
  # source_security_group_id = aws_security_group.nsg_eb.id
# }
######## EVENT BRIDGE ##########

resource "aws_cloudwatch_event_bus" "event-bus" {
  name = "carrier-response"
 # event_source_name = "aws.lambda"
}

resource "aws_cloudwatch_event_rule" "event_rule_stratus" {
  name = "quoteType-event-rule-stratus"
  description = "create a rule matching a pattern"
  event_bus_name = aws_cloudwatch_event_bus.event-bus.name
 
  event_pattern = <<EOF
  {
	"source": ["Lambda-Carrier-Events"],
	  "detail-type": ["Carrier-Responses"],
	    "detail": {
	    "clientType": ["Stratus"]
	  }
  }
EOF
}

resource "aws_cloudwatch_event_rule" "event_rule_browser" {
  name = "quoteType-event-rule-browser"
  description = "create a rule matching a pattern"
  event_bus_name = aws_cloudwatch_event_bus.event-bus.name
 
  event_pattern = <<EOF
  {
	"source": ["Lambda-Carrier-Events"],
	  "detail-type": ["Carrier-Responses"],
	    "detail": {
	    "clientType": ["Browser"]
	  }
  }
EOF
}

# EVENT BRIDGE TARGET -  API Destination-1

resource "aws_cloudwatch_event_target" "target_api_destination_1" {
  rule = aws_cloudwatch_event_rule.event_rule_stratus.name
  event_bus_name = aws_cloudwatch_event_bus.event-bus.name
  arn = aws_cloudwatch_event_api_destination.eb_target_api_1.arn
  role_arn = aws_iam_role.eb_role.arn
}

# EVENT BRIDGE TARGET -  API Destination-1
resource "aws_cloudwatch_event_target" "target_api_destination_2" {
  rule = aws_cloudwatch_event_rule.event_rule_browser.name
  event_bus_name = aws_cloudwatch_event_bus.event-bus.name
  arn = aws_cloudwatch_event_api_destination.eb_target_api_2.arn
  role_arn = aws_iam_role.eb_role.arn
}

# IAM ROLE to INVOKE API DESTINATION

resource "aws_iam_role" "eb_role" {
    name = "eb-role-to-invoke-api-destination"
    assume_role_policy = <<EOF
    {
        "Version" : "2012-10-17",
        "Statement" : [
            {
            "Action" : "sts:AssumeRole",
            "Principal" : {
                "Service" : "events.amazonaws.com"
            },
            "Effect" : "Allow",
            "Sid" : ""
            }
        ]
    }
    EOF
}

resource "aws_iam_policy" "iam_policy_to_invoke_api_destination" {
 
 name         = "aws-iam-policy-for-eb-invoking-api-destination"
 path         = "/"
 description  = "AWS IAM Policy for invoking api destination"
 policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "events:InvokeApiDestination"
     ],
     "Resource": "arn:aws:events:*:*:*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

# Attach IAM Policy to IAM Role

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role_events" {
 role        = aws_iam_role.eb_role.name
 policy_arn  = aws_iam_policy.iam_policy_to_invoke_api_destination.arn
}


# EVENT BRIDGE TARGET - LAMBDA (No longer needed as destination for EB is now a webhook(API destination)). 

# resource "aws_cloudwatch_event_target" "target-lambda-function" {
#   rule = aws_cloudwatch_event_rule.event-rule.name
#   event_bus_name = aws_cloudwatch_event_bus.event-bus.name
#   arn = aws_lambda_function.response-lambda.arn
# }



# resource "aws_lambda_permission" "allow-cloudwatch" {
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.response-lambda.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.event-rule.arn
# }

# resource "aws_lambda_function" "response-lambda" {
#   function_name = "demo-alb-lambda-response-test"
#   filename         = data.archive_file.lambda_zip_file.output_path
#   source_code_hash = data.archive_file.lambda_zip_file.output_base64sha256
#   role    = aws_iam_role.response-lambda-role.arn
#   handler = "ResponseQuoteEvent.lambda_handler"
#   runtime = "python3.9"
# }

# data "archive_file" "lambda_zip_file" {
#   type = "zip"
#   source_file = "/Users/phanisurapaneni/Documents/BRP/API_POC/ResponseQuoteEvent.py"
#   output_path = "/Users/phanisurapaneni/Documents/BRP/API_POC/ResponseQuoteEvent.zip"
# }

# data "aws_iam_policy" "lambda_basic_execution_role_policy" {
#   name = "AWSLambdaBasicExecutionRole"
# }

# resource "aws_iam_role" "response-lambda-role" {
#   name = "demo-alb-eb-response-lambda-role"
#   managed_policy_arns = [data.aws_iam_policy.lambda_basic_execution_role_policy.arn]

#   assume_role_policy = <<EOF
#   {
#     "Version": "2012-10-17",
#     "Statement": [
#     {
#       "Action": "sts:AssumeRole",
#       "Principal": {
#       "Service": "lambda.amazonaws.com"
#       },
#       "Effect": "Allow",
#       "Sid": ""
#     }
#     ]
#   }
#   EOF
# }

# Custom EB TARGET TO API DESTINATION -1 

resource "aws_cloudwatch_event_api_destination" "eb_target_api_1" {
  name                             = "webhook-api-destination-1"
  description                      = "Webhook API Destination"
  invocation_endpoint              = "https://webhook.site/f0abd0a6-8238-4517-b5ba-2a42bbe21972"
  http_method                      = "POST"
  invocation_rate_limit_per_second = 300
  connection_arn                   = aws_cloudwatch_event_connection.eb_wh_connection_1.arn
}

resource "aws_cloudwatch_event_connection" "eb_wh_connection_1" {
  name               = "demo-connection-1"
  description        = "Connection to test webhook safari"
  authorization_type = "BASIC"

  auth_parameters {
    basic {
      username = "test"
      password = "secret"
    }
  }
}

# Custom EB TARGET TO API DESTINATION -2 

resource "aws_cloudwatch_event_api_destination" "eb_target_api_2" {
  name                             = "webhook-api-destination-2"
  description                      = "Webhook API Destination 2"
  invocation_endpoint              = "https://webhook.site/ed263932-dc59-466e-bffd-4883486fbfb4"
  http_method                      = "POST"
  invocation_rate_limit_per_second = 300
  connection_arn                   = aws_cloudwatch_event_connection.eb_wh_connection_2.arn
}

resource "aws_cloudwatch_event_connection" "eb_wh_connection_2" {
  name               = "demo-connection-2"
  description        = "Connection to test webhook chrome"
  authorization_type = "BASIC"

  auth_parameters {
    basic {
      username = "test-2"
      password = "secret-2"
    }
  }
}

# SF-EB INTEGRATION sample oauth setup

# resource "aws_cloudwatch_event_api_destination" "eb_target_api" {
#   name                             = "sf-api-destination"
#   description                      = "SalesForce API Destination"
#   invocation_endpoint              = "https://brpstratus--sit.sandbox.my.salesforce.com/services/apexrest/submitquote/"
#   http_method                      = "POST"
#   invocation_rate_limit_per_second = 300
#   connection_arn                   = aws_cloudwatch_event_connection.eb_sf_connection.arn
# }

# resource "aws_cloudwatch_event_connection" "eb_sf_connection" {
#   name               = "qbi-connection"
#   description        = "connection to salesforce"
#   authorization_type = "OAUTH_CLIENT_CREDENTIALS"

#   auth_parameters {
#     oauth {
#         authorization_endpoint = "https://brpstratus--sit.sandbox.my.salesforce.com/services/oauth2/token"
#         http_method = "GET"

#         client_parameters {
#         client_id     = "3MVG9_I_oWkIqLrl7h.HM0nqegStK_Ap.vdj.Pr7m0zqwIPc0ZQa6TiQ7S5Q2zKr0x8CsWG_ULfZ.4NIf2jaM"
#         client_secret = "REPLACE WITH CLIENT SECRET"
#         }

#       oauth_http_parameters {
#         body {
#           key             = "grant_type"
#           value           = "password"
#           is_value_secret = false
#         }

#         body {
#           key             = "username"
#           value           = "mulesoft@baldwinriskpartners.com.stratus.sit"
#           is_value_secret = false
#         }

#         body {
#           key             = "password"
#           value           = "REFER SECRET PASSWORD"
#           is_value_secret = true
#         }
#       }
#     }
#   }
# }


// API Gateway stuff to manage webhooks

#Define the use of rest API
resource "aws_api_gateway_rest_api" "api" {
  name = "eb-connection"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# The resource for the endpoint
resource "aws_api_gateway_resource" "lambda_eb" {
  path_part   = "updateEBConnection"
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.api.id
}

# How the gateway will be interacted from clientt
resource "aws_api_gateway_method" "lambda_eb" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.lambda_eb.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "redirect" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.lambda_eb.id
  http_method = aws_api_gateway_method.lambda_eb.http_method
  # Lambda invokes requires a POST method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_update_eb_conn.invoke_arn
}

# resource "aws_cloudwatch_log_group" "api_gw" {
#   name = "/aws/api_gw/${aws_api_gateway_rest_api.api.name}"

#   retention_in_days = var.apigw_log_retention
# }

resource "aws_api_gateway_deployment" "update_con_apig_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name = "ebconnection-beta"

  depends_on       = [aws_api_gateway_integration.redirect]
}

resource "aws_api_gateway_account" "apig_cw_role" {
  cloudwatch_role_arn = aws_iam_role.iam_role_for_apig_cw.arn
}

resource "aws_api_gateway_method_settings" "apig_cw_settings" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_deployment.update_con_apig_deployment.stage_name

  method_path = "*/*"
  settings {
    logging_level = "INFO"
    data_trace_enabled = true
    metrics_enabled = true
  }
}

resource "aws_lambda_permission" "allow_api_gw_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_update_eb_conn.function_name
  principal     = "apigateway.amazonaws.com"

 # source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}