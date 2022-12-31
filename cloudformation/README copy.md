# Amazon Route53 Hosted Zone record replication (Public to Private)

This repository shows an example of DNS record replication between two [Amazon Route 53](https://aws.amazon.com/route53/) Hosted Zones. In this specific example, the replication is done between the records created in a Public Hosted Zone (owned by you) and a Private Hosted Zone (created in the example). The Private Hosted Zone will have the same zone name as the Public Hosted Zone. Why? Because we want to show how you can sync a Public and Private Hosted Zones to allow resolution of public records inside your VPC while you can keep some specific private resolution.

![Architecture](./image/route53-sync.png "Solution's diagram")

This example builds the following resources:

* [Amazon EventBridge rule](https://aws.amazon.com/eventbridge/) that takes the changes done in the Amazon Route 53 (and tracked in [AWS CloudTrail](https://aws.amazon.com/cloudtrail/)) and targets an [AWS Lambda](https://aws.amazon.com/lambda/) function.
* AWS Lambda function, that processes the record changes in the Public Hosted Zone and applies them in the Private Hosted Zone.
* Private Hosted Zone, with the same name as the Public Hosted Zone you provide.
* An [Amazon VPC](https://aws.amazon.com/vpc/), with [Amazon EC2](https://aws.amazon.com/ec2/) instances and [AWS System Manager](https://aws.amazon.com/systems-manager/) VPC endpoints to test the DNS resolution between the Public and Private Hosted Zones.
* AWS IAM roles for the Lambda function and EC2 instance.

You have both code in AWS CloudFormation or Terraform to build the solution, and you can find the Lambda function code (in Python) in the *lambda* folder.

## Why this pattern?

One common question when doing DNS resolution with Route 53 is: can I have specific DNS resolution for my internal services using a Private Hosted Zone (let's say *internal.example.com*), while for the rest of records (for example *public.example.com*) they can query a Public Hosted Zone?

In other words, the expected behavior is to have two Hosted Zones (Public and Private) with the Private one associated with VPC(s), and different records in each of them. That way EC2 instances located in the VPC(s) will query the Route 53 resolver in the VPC, and they will get private resolution from the Private Hosted Zone, and if they don't find the record there, they will query the Public Hosted Zone. However, the DNS resolution in the VPC does not work like that:

* When the EC2 instance needs DNS resolution, it will query the Route 53 resolver (VPC + 2).
* The Route 53 Resolver looks at the query name, and the VPC it comes from. Then it checks the zone of this domain name in the following order:
  * The list of Private Hosted Zones associated with the VPC.
  * VPC DNS - EC2 instance names.
  * If by this time it does not find any match, it will do usual public resolution (Public Hosted Zones)
* Once it finds the Hosted Zone with the same name as the query name, it will check the specific record in that Hosted Zone.

In the use case we covering, where we have a Private and a Public Hosted Zone with the same name, if a specific record is not found in the Private Hosted Zone the Resolver won't check any Public Hosted Zone. So... how can we architect the desired behavior? By syncing records between both the Public and Private Hosted Zones (usually from the Public to the Private), except those ones selected (because they are specific to be public or private), EC2 instances in the VPCs will be able to have:

* Private DNS resolution, by configuring records directly in the Private Hosted Zone.
* Public DNS resolution, from the records synced from the Public Hosted Zone.

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

## Pre-Requisites

* An AWS Account with an IAM user that has appropriate permissions.
* An Amazon Route 53 Public Hosted Zone, as the IaC examples will ask for its zone ID and name.
* If you want to use the Terraform example, Terraform should be installed.

## References

* [Amazon Route 53 Documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html)
* [Route53 - Boto3 Docs](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/route53.html)
* [Amazon EventBridge Documentation](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-what-is.html)

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.