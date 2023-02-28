#!/bin/bash

# define variables for CIDR and AZ
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
AZ="us-west-2a"

# Create a new VPC
vpc_id=$(aws ec2 create-vpc --cidr-block $VPC_CIDR | yq '.Vpc.VpcId')
echo "VPC ID $vpc_id"

# Create a new subnet in the VPC created above
# For longer commands you can use \ to split up your command into several lines
subnet_id=$(
  aws ec2 create-subnet \
  --cidr-block $SUBNET_CIDR \
  --availability-zone $AZ \
  --vpc-id $vpc_id \
  | yq '.Subnet.SubnetId'
)
echo "Subnet ID $subnet_id"

