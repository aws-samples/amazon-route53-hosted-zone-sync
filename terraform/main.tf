# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# --- root/main.tf ---

# ---------- PRIVATE HOSTED ZONE ----------
resource "aws_route53_zone" "private_hostedzone" {
  provider = aws.awsmain
  name     = var.zone_name

  vpc {
    vpc_id = module.vpc.vpc_attributes.id
  }
}

# ---------- AMAZON EVENTBRIDGE RULE ----------
# Rule resource
resource "aws_cloudwatch_event_rule" "eventbridge_rule" {
  provider = aws.awsnvirginia

  name        = "route53-publichostedzone-changes-${var.identifier}"
  description = "Captures Changes in Route53 Public Hosted Zones."

  event_pattern = <<EOF
    {
        "source": ["aws.route53"],
        "detail-type": ["AWS API Call via CloudTrail"],
        "detail": {
            "eventSource": ["route53.amazonaws.com"],
            "eventName": ["ChangeResourceRecordSets"],
            "requestParameters": {
              "hostedZoneId": ["${var.public_hosted_zone_id}"]
            }
        }
    }
EOF
}

# Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  provider = aws.awsnvirginia

  arn  = aws_lambda_function.lambda_route53_function.arn
  rule = aws_cloudwatch_event_rule.eventbridge_rule.id
}

# Lambda permission (for the EventBridge rule)
resource "aws_lambda_permission" "allow_eventbridge_rule" {
  provider = aws.awsnvirginia

  statement_id  = "EventBridgeToLambda"
  action        = "lambda:InvokeFunction"
  function_name = "update_hosted_zone-${var.identifier}"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.eventbridge_rule.arn
}

# ---------- LAMBDA FUNCTION ----------
# Lambda function
resource "aws_lambda_function" "lambda_route53_function" {
  provider = aws.awsnvirginia

  function_name    = "update_hosted_zone-${var.identifier}"
  filename         = "lambda_function.zip"
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256

  role    = aws_iam_role.lambda_role.arn
  runtime = "python3.9"
  handler = "lambda_function.lambda_handler"
  timeout = 10

  environment {
    variables = {
      DONT_UPDATE            = var.alias_dont_update
      PRIVATE_HOSTED_ZONE_ID = aws_route53_zone.private_hostedzone.zone_id
    }
  }
}

data "archive_file" "python_lambda_package" {
  type        = "zip"
  source_file = "../lambda/lambda_function.py"
  output_path = "lambda_function.zip"
}

# IAM Role
resource "aws_iam_role" "lambda_role" {
  provider = aws.awsnvirginia

  name = "lambda-route53-role_${var.identifier}"
  path = "/"

  assume_role_policy = data.aws_iam_policy_document.lambda_assum_role_policy.json
}

data "aws_iam_policy_document" "lambda_assum_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Policy - CloudWatch Logging and Route53 Update
resource "aws_iam_policy" "lambda_policy" {
  provider = aws.awsnvirginia

  name        = "lambda_policy-${var.identifier}"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = data.aws_iam_policy_document.lambda_policy_document.json
}

data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    sid    = "LambdaLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid       = "Route53Update"
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [aws_route53_zone.private_hostedzone.arn]
  }
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  provider = aws.awsnvirginia

  name       = "lambda-logging-policy-attachment_${var.identifier}"
  roles      = [aws_iam_role.lambda_role.id]
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  provider = aws.awsnvirginia

  name              = "/aws/lambda/update_hosted_zone-${var.identifier}"
  retention_in_days = 7
}

# ---------- VPC ----------
module "vpc" {
  providers = {
    aws   = aws.awsmain
    awscc = awscc.awsccmain
  }
  source  = "aws-ia/vpc/aws"
  version = "3.1.0"

  name       = "vpc-${var.identifier}"
  cidr_block = local.vpc_information.cidr_block
  az_count   = local.vpc_information.az_count

  subnets = {
    workloads = { netmask = local.vpc_information.netmask.workloads }
    endpoints = { netmask = local.vpc_information.netmask.endpoints }
  }
}

# Security groups
resource "aws_security_group" "vpc_sg" {
  provider = aws.awsmain
  for_each = local.security_groups

  name        = each.value.name
  description = each.value.description
  vpc_id      = module.vpc.vpc_attributes.id

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      description = ingress.value.description
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = each.value.egress
    content {
      description = egress.value.description
      from_port   = egress.value.from
      to_port     = egress.value.to
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = {
    Name = "${each.key}-security-group-${var.identifier}"
  }
}

# ---------- COMPUTE ----------
# Linux 2 AMI
data "aws_ami" "amazon_linux" {
  provider    = aws.awsmain
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"
    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"
    values = [
      "amazon",
    ]
  }
}

# EC2 INSTACE (1 per AZ in each VPC)
resource "aws_instance" "ec2_instance" {
  provider = aws.awsmain
  count    = local.vpc_information.az_count

  ami                         = data.aws_ami.amazon_linux.id
  associate_public_ip_address = false
  instance_type               = local.vpc_information.instance_type
  vpc_security_group_ids      = [aws_security_group.vpc_sg["instance"].id]
  subnet_id                   = values({ for k, v in module.vpc.private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "workloads" })[count.index]
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.id

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "instance-${count.index + 1}-${var.identifier}"
  }
}

# ---------- IAM ROLE (EC2 ACCESS TO SSM) ---------
# IAM instance profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  provider = aws.awsmain
  name     = "ec2_instance_profile_${var.identifier}"
  role     = aws_iam_role.role_ec2.id
}

# IAM role
data "aws_iam_policy_document" "policy_document" {
  statement {
    sid     = "1"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

  }
}

resource "aws_iam_role" "role_ec2" {
  provider           = aws.awsmain
  name               = "ec2_ssm_role_${var.identifier}"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.policy_document.json
}

# Policies Attachment to Role
resource "aws_iam_policy_attachment" "ssm_iam_role_policy_attachment" {
  provider   = aws.awsmain
  name       = "ssm_iam_role_policy_attachment_${var.identifier}"
  roles      = [aws_iam_role.role_ec2.id]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ---------- VPC ENDPOINTS ----------
resource "aws_vpc_endpoint" "endpoint" {
  provider = aws.awsmain
  for_each = local.endpoint_service_names

  vpc_id              = module.vpc.vpc_attributes.id
  service_name        = each.value.name
  vpc_endpoint_type   = each.value.type
  subnet_ids          = values({ for k, v in module.vpc.private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "endpoints" })
  security_group_ids  = [aws_security_group.vpc_sg["vpc_endpoints"].id]
  private_dns_enabled = each.value.private_dns
}