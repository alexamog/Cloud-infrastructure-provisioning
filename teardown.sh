#!/bin/bash
set -o nounset # Treat unset variables as an error

## Tear down RDS
aws rds delete-db-instance \
    --db-instance-identifier mydbinstance \
    --final-db-snapshot-identifier mydbinstancefinalsnapshot \
    --delete-automated-backups

## Tear down RDS sec group
aws rds delete-db-security-group \
    --db-security-group-name ""
## Tear down EC2 instance
aws ec2 terminate-instances \
    --instance-ids ""

## Tear down Elastic IP
aws ec2 release-address --public-ip


## Delete subnets
aws ec2 delete-subnet --subnet-id ""

## Tear down VPC
aws delete-vpc --vpc-id ""