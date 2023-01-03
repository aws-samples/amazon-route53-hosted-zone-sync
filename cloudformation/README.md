# Amazon Route53 Hosted Zone record replication (Public to Private) - AWS CloudFormation

![Architecture](../image/route53-sync.png "Solution's diagram")

## Deployment instructions

* Clone the repository.
* Add in the **Makefile** the Public Hosted Zone ID and name, and the list of aliases that shouldn't be synced with the Private Hosted Zone.
* `make deploy` will build two stacks: *VpcCompute.yaml* will create the VPC resources, EC2 instances and Private Hosted Zone; while *Architecture.yaml* will create the Serverless resources (EventBridge rule, Lambda function, IAM roles).
* `make undeploy` will delete both stacks.

## Pre-Requisites

* An AWS Account with an IAM user that has appropriate permissions.
* An Amazon Route 53 Public Hosted Zone, as the IaC examples will ask for its zone ID and name.

## Security

See [CONTRIBUTING](../CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.