# Amazon Route53 Hosted Zone record replication (Public to Private)

This repository shows an example of DNS record replication from an [Amazon Route 53](https://aws.amazon.com/route53/) public hosted zone to a private hosted zone - both with the same domain name. **What do we want to solve with this solution?** Let's say that you want resources in your VPC to have public resolution as your external users (with a public hosted zone), except you want also specific private resolution using a private hosted zone. 

As stated in the [AWS Documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-considerations.html#:~:text=53%20Resolver%3F.-,Public%20and%20private%20hosted%20zones%20that%20have%20overlapping%20namespaces,-If%20you%20have), if there's a matching domain name between a public and a private hosted zone, the VPC Resolver does not forward requests from the private to the public one if a record is not found. This means you need to sync changes between hosted zones, except those records that don't require update.

![Architecture](./image/route53-sync.png "Solution's diagram")

This example builds the following resources:

* [Amazon EventBridge rule](https://aws.amazon.com/eventbridge/) that takes the changes done in the Amazon Route 53 (and tracked in [AWS CloudTrail](https://aws.amazon.com/cloudtrail/)) and targets an [AWS Lambda](https://aws.amazon.com/lambda/) function.
* AWS Lambda function, that processes the record changes in the Public Hosted Zone and applies them in the Private Hosted Zone.
* Private Hosted Zone, with the same name as the Public Hosted Zone you provide.
* An [Amazon VPC](https://aws.amazon.com/vpc/), with [Amazon EC2](https://aws.amazon.com/ec2/) instances and [AWS System Manager](https://aws.amazon.com/systems-manager/) VPC endpoints to test the DNS resolution between the Public and Private Hosted Zones.
* AWS IAM roles for the Lambda function and EC2 instance.

## How can I deploy the solution?

You have code to deploy this architecture with in [AWS CloudFormation](/cloudformation) or [Terraform](/terraform). Check the README in each folder to deploy the solution, taking into account the following **pre-requisities**:

* An AWS Account with an IAM user that has appropriate permissions.
* An Amazon Route 53 Public Hosted Zone, as the IaC examples will ask for its zone ID and name.
* If you want to use the Terraform example, Terraform should be installed.

## How does it work?

All the actions done in Route 53 are recorded by CloudTrail in **us-east-1**, and that's why the Serverless resources are located in that AWS Region. The EventBride rule has an event pattern, so it is only triggered when there are Route 53 actions (API calls via CloudTrail) to the Hosted Zone we indicate, and the specific event is *ChangeResourceRecordSets* (creating, deleting or updating records).

```json
{
    "source": ["aws.route53"],
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
        "eventSource": ["route53.amazonaws.com"],
        "eventName": ["ChangeResourceRecordSets"],
        "requestParameters": {
            "hostedZoneId": ["${HOSTED_ZONE_ID}"]
        }
    }
}
```
Once the event is triggered, it invokes a Lambda function that performs three actions:

* Checks the different changes applied to the Hosted Zone, and filters those ones that are records tagged as *don't update*.
* For the changes that need an action, it needs to transform the keys of the declaration and capitalize the first letter of all of them - to comply with the format of boto3 (the Lambda is written in Python).
* It does a *ChangeResourceRecordSets* against the Private Hosted Zone.

The VPC resources, EC2 instance, and SSM VPC endpoints are created for testing purposes, and you can select in which AWS Region they are located - that way you can practice how this solution works in multi-Region environments.

**What about multi-Account?** In the case you want to update a Hosted Zone in another AWS account, you can do two things:

* You can configure EventBridge to [send and receive events between event buses in AWS different AWS Accouns](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-cross-account.html).
* Your AWS Lambda [can assume an IAM role in another AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/lambda-function-assume-iam-role/), with enough permissions to perform the action *ChangeResourceRecordSets* in the desired Hosted Zone.
* You can to keep the Private Hosted Zone in the same AWS Account, and [associate it to a VPC in a different AWS Account](https://aws.amazon.com/premiumsupport/knowledge-center/route53-private-hosted-zone/).

## References

* [Amazon Route 53 Documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html)
* [Route53 - Boto3 Docs](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/route53.html)
* [Amazon EventBridge Documentation](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-what-is.html)

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.