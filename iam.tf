# Script to manage IAM roles and policies for project

# Role for alb to execute lambda to Request Quote
resource "aws_iam_role" "lambda_role" {
    name = "demo-alb-lambda-role"
    assume_role_policy = <<EOF
    {
        "Version" : "2012-10-17",
        "Statement" : [
            {
            "Action" : "sts:AssumeRole",
            "Principal" : {
                "Service" : "lambda.amazonaws.com"
            },
            "Effect" : "Allow",
            "Sid" : ""
            }
        ]
    }
    EOF
}

# Add IAM policy
resource "aws_iam_policy" "iam_policy_for_lambda" {
 
 name         = "aws_iam_policy_for_terraform_aws_lambda_role"
 path         = "/"
 description  = "AWS IAM Policy for managing aws lambda role"
 policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*",
     "Effect": "Allow"
   },
   {
     "Action": [
       "events:*"
     ],
     "Resource": "*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

#Attach IAM Policy to IAM Role 
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
 role        = aws_iam_role.lambda_role.name
 policy_arn  = aws_iam_policy.iam_policy_for_lambda.arn
}

# Role for alb to execute lambda (used for updating EB connection credentials)
resource "aws_iam_role" "lambda_role_update_eb_conn" {
    name = "demo-alb-lambda-role-update-eb-connections"
    assume_role_policy = <<EOF
    {
        "Version" : "2012-10-17",
        "Statement" : [
            {
            "Action" : "sts:AssumeRole",
            "Principal" : {
                "Service" : "lambda.amazonaws.com"
            },
            "Effect" : "Allow",
            "Sid" : ""
            }
        ]
    }
    EOF
}

# Policy to execute lambda used to update EB connection credentials
resource "aws_iam_policy" "iam_policy_for_lambda_eb_conn" {
 
 name         = "aws-iam-policy-update-eb-connections"
 path         = "/"
 description  = "AWS IAM Policy for managing aws lambda role to update eb connections"
 policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*",
     "Effect": "Allow"
   },
   {
     "Action": [
       "events:*"
     ],
     "Resource": "*",
     "Effect": "Allow"
   },
   {
     "Action": [
       "secretsmanager:*"
     ],
     "Resource": "*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

#Attach IAM Policy to IAM Role 
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role_eb_conn" {
 role        = aws_iam_role.lambda_role_update_eb_conn.name
 policy_arn  = aws_iam_policy.iam_policy_for_lambda_eb_conn.arn
}

# Give load balancing service access to the bucket
resource "aws_s3_bucket_policy" "lb_access_logs" {
  bucket = aws_s3_bucket.lb_access_logs.id

  policy = <<POLICY
{
  "Id": "Policy",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.lb_access_logs.arn}",
        "${aws_s3_bucket.lb_access_logs.arn}/*"
      ],
      "Principal": {
        "AWS": [ "${data.aws_elb_service_account.main.arn}" ]
      }
    }
  ]
}
POLICY
}

# IAM role and policy for APIGateway to push to cloudwatch

resource "aws_iam_role" "iam_role_for_apig_cw" {
    name = "apig-cw-role"
    assume_role_policy = <<EOF
    {
        "Version" : "2012-10-17",
        "Statement" : [
            {
                "Sid": "",
                "Effect": "Allow",
                "Principal": {
                    "Service": "apigateway.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    EOF
}

resource "aws_iam_policy" "iam_policy_for_apig_cw" {
 name         = "apig-cw-policy"
 path         = "/"
 description  = "AWS IAM Policy for managing aws lambda role to update eb connections"
 policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

#Attach IAM Policy to IAM Role 
resource "aws_iam_role_policy_attachment" "attach_apig_role_to_policy" {
 role        = aws_iam_role.iam_role_for_apig_cw.name
 policy_arn  = aws_iam_policy.iam_policy_for_apig_cw.arn
}