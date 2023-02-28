#!/bin/bash

aws ec2 describe-images --region us-west-2 \
 --filters Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server* \
 --query 'sort_by(Images, &CreationDate)[-1].{Name: Name, ImageId: ImageId, CreationDate: CreationDate, Owner:OwnerId}' \

