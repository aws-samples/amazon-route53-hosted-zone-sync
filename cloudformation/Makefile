.PHONY: deploy undeploy

# Variables
PUBLIC_HOSTED_ZONE_ID = <ADD INFO>
ZONE_NAME = <ADD INFO>
ALIAS_DONT_UPDATE = <ADD INFO>
VPC_COMPUTE_REGION = eu-west-1

# Stack names
ARCHITECTURE_STACK_NAME ?= lambda-architecture
VPC_COMPUTE_STACK_NAME ?= vpc-compute

deploy: deploy-vpccompute deploy-architecture

deploy-vpccompute: 
	aws cloudformation deploy --stack-name "${VPC_COMPUTE_STACK_NAME}" --template-file VpcCompute.yaml --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset --region "${VPC_COMPUTE_REGION}"

deploy-architecture: VPC_ID = $(shell aws cloudformation describe-stacks --stack-name "$(VPC_COMPUTE_STACK_NAME)" --query 'Stacks[0].Outputs[?OutputKey == `VpcId`].OutputValue' --output text --region "${VPC_COMPUTE_REGION}" )
deploy-architecture:
	aws cloudformation deploy --stack-name "${ARCHITECTURE_STACK_NAME}" --template-file Architecture.yaml --capabilities CAPABILITY_IAM --parameter-overrides PublicHostedZoneId="${PUBLIC_HOSTED_ZONE_ID}" ZoneName="${ZONE_NAME}" AliasDontUpdate="${ALIAS_DONT_UPDATE}" VpcId="${VPC_ID}" VpcRegion="${VPC_COMPUTE_REGION}" --no-fail-on-empty-changeset --region us-east-1

undeploy: VPC_COMPUTE_STACK_ID = $(shell aws cloudformation list-stacks --region "${VPC_COMPUTE_REGION}" | jq '.StackSummaries[] | select(.StackStatus=="DELETE_COMPLETE" | not)' | jq 'select(.StackName=="${VPC_COMPUTE_STACK_NAME}")' | jq .StackId -r)
undeploy: ARCHITECTURE_STACK_ID = $(shell aws cloudformation list-stacks --region us-east-1 | jq '.StackSummaries[] | select(.StackStatus=="DELETE_COMPLETE" | not)' | jq 'select(.StackName=="${VPC_COMPUTE_STACK_NAME}")' | jq .StackId -r)
undeploy: 
	aws cloudformation delete-stack --stack-name "${ARCHITECTURE_STACK_NAME}" --region us-east-1
	aws cloudformation wait stack-delete-complete --stack-name "${ARCHITECTURE_STACK_ID}" --region us-east-1
	aws cloudformation delete-stack --stack-name "${VPC_COMPUTE_STACK_NAME}" --region "${VPC_COMPUTE_REGION}"
	aws cloudformation wait stack-delete-complete --stack-name "${VPC_COMPUTE_STACK_ID}" --region "${VPC_COMPUTE_REGION}"
