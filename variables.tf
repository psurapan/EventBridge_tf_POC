variable "aws_region" {
  description = "Default region for provider"
  type = string
  default     = "us-east-1"
}

variable "accessKey" {
  default = ""
}

variable "secretKey" {
  default = ""
}

# A map of the tags to apply to various resources. The required tags are:
# 'application', name of the app;
# 'environment', the environment being created;
# 'team', team responsible for the application;
# 'customer', who the application was create for.
variable "tags" {
  type = map 
  default = {
    Application = "demo-alb-eb"
    Environment = "dev"
    Team = "accolite/xerris"
    Customer = "brp"
  }
}

# The application's name
variable "app" {
  default = "demo-alb-eb"
}

# The environment that is being built
variable "environment" {
  default = "test"
}

variable "lb_port" {
  default = "80"
}

variable "lb_protocol" {
  default = "HTTP"
}

variable "subnet_cidrs_public" {
  type = list
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "AZs in this region to use"
  type = list
  default = ["us-east-1a", "us-east-1c"]
}

variable "apigw_log_retention" {
  description = "api gwy log retention in days"
  type = number
  default = 7
}

#variable "public_subnets" {}