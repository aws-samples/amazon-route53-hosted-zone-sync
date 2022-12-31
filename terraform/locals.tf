# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# --- root/locals.tf ---

locals {
  vpc_information = {
    cidr_block = "10.128.0.0/24"
    az_count   = 1
    netmask = {
      workloads = 28
      endpoints = 28
    }
    instance_type = "t3.micro"
  }

  security_groups = {
    vpc_endpoints = {
      name        = "endpoints_sg"
      description = "Security Group for SSM connection"
      ingress = {
        https = {
          description = "Allowing HTTPS"
          from        = 443
          to          = 443
          protocol    = "tcp"
          cidr_blocks = [local.vpc_information.cidr_block]
        }
      }
      egress = {
        any = {
          description = "Any traffic"
          from        = 0
          to          = 0
          protocol    = "-1"
          cidr_blocks = [local.vpc_information.cidr_block]
        }
      }
    }
    instance = {
      name        = "instance_sg"
      description = "Security Group for EC2 instances."
      ingress = {
        icmp = {
          description = "Allowing any traffic from the same VPC"
          from        = 0
          to          = 0
          protocol    = "-1"
          cidr_blocks = [local.vpc_information.cidr_block]
        }
      }
      egress = {
        any = {
          description = "Any traffic"
          from        = 0
          to          = 0
          protocol    = "-1"
          cidr_blocks = [local.vpc_information.cidr_block]
        }
      }
    }
  }

  endpoint_service_names = {
    ssm = {
      name        = "com.amazonaws.${var.aws_region}.ssm"
      type        = "Interface"
      private_dns = true
    }
    ssmmessages = {
      name        = "com.amazonaws.${var.aws_region}.ssmmessages"
      type        = "Interface"
      private_dns = true
    }
    ec2messages = {
      name        = "com.amazonaws.${var.aws_region}.ec2messages"
      type        = "Interface"
      private_dns = true
    }
  }
}