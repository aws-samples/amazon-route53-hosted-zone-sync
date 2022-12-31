# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# --- root/providers.tf ---

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.73.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 0.15.0"
    }
  }
}

# AWS Provider configuration - AWS Region indicated in root/variables.tf
provider "aws" {
  region = var.aws_region
  alias  = "awsmain"
}

provider "awscc" {
  region = var.aws_region
  alias  = "awsccmain"
}

# AWS Provider configuration (us-east-1) for the resources related to Amazon Route53
provider "aws" {
  region = "us-east-1"
  alias  = "awsnvirginia"
}