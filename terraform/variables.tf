# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# --- root/variables.tf ---

variable "identifier" {
  description = "Project identifier."
  type        = string
  default     = "route53-hostedzone-sync"
}

variable "public_hosted_zone_id" {
  description = "Public Hosted Zone ID - the source."
  type        = string
}

variable "zone_name" {
  description = "Public Hosted Zone name - to create the Private Hosted Zone."
  type        = string
}

variable "alias_dont_update" {
  description = "Alias(es) to not update between Hosted Zones"
  type        = string
}

variable "aws_region" {
  description = "AWS Region to use."
  type        = string
  default     = "eu-west-2"
}