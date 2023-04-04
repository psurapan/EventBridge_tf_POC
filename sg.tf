##### Security GROUPS #####

# Ingress rules to allow ALB calls
resource "aws_security_group_rule" "ingress_lb_http" {
  type              = "ingress"
  description       = var.lb_protocol
  from_port         = var.lb_port
  to_port           = var.lb_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nsg_lb.id
}

# security group for lambda 
resource "aws_security_group" "nsg_lb" {
  # name        = "${var.app}-${var.environment}-lb"
  name        = "${var.app}-${var.environment}-lb"
  description = "Allow connections from external resources while limiting connections from ${var.app}-${var.environment}-lb to internal resources"
  vpc_id      = aws_vpc.demo_vpc.id

  tags = "${var.tags}"
}

# security group for lambda, ingress for lb and egress to event bridge
resource "aws_security_group" "nsg_lambda" {
  name        = "${var.app}-${var.environment}-lambda"
  description = "Limit connections from internal resources while allowing ${var.app}-${var.environment}-lambda to connect to all external resources"
  vpc_id      = aws_vpc.demo_vpc.id

  tags = "${var.tags}"
}

# security group to egress only to lambda
resource "aws_security_group_rule" "nsg_lb_egress_rule" {
  security_group_id = aws_security_group.nsg_lb.id
  description = "Only allow SG ${var.app}-${var.environment}-lb to connect to ${var.app}-${var.environment}-lambda on port ${var.lb_port}"
  type = "egress"
  from_port = var.lb_port
  to_port = var.lb_port
  protocol = "tcp"
  source_security_group_id = aws_security_group.nsg_lambda.id
  #cidr_blocks = ["0.0.0.0/0"]
  #ipv6_cidr_blocks = ["::0"]
}

# security group for lambda
resource "aws_security_group_rule" "nsg_lambda_ingress_rule" {
  security_group_id        = aws_security_group.nsg_lambda.id
  description              = "Only allow connections from SG ${var.app}-${var.environment}-lb on port ${var.lb_port}"
  type                     = "ingress"
  from_port = var.lb_port
  to_port = var.lb_port
  protocol = "tcp"
  source_security_group_id = aws_security_group.nsg_lb.id
    #cidr_blocks = ["0.0.0.0/0"]
  }

# Lambda egress for all resources 
resource "aws_security_group_rule" "nsg_lambda_egress_rule" {
  security_group_id = aws_security_group.nsg_lambda.id
  description       = "Allows lambda to establish connections to all resources"
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}