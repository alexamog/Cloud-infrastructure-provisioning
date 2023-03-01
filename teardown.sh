#!/usr/bin/env bash

set -o nounset # Treat unset variables as an error

# Assume that the state file is in the same directory as this script
declare -r script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" #can't symlink this script
declare -r state_file="$script_dir/state_file"

source "${state_file}" # get data from state_file

ec2_instance_delete() {
  declare _instance_id="$1"
  echo -e "\n** EC2 Instance ID ${_instance_id} **"

  if aws ec2 describe-instances --instance-ids "${_instance_id}" --output table --no-cli-pager; then # check if instance exists
    if aws ec2 terminate-instances --instance-ids "${_instance_id}"; then
      # Wait for instance to terminate
      aws ec2 wait instance-terminated --instance-ids "${_instance_id}"
      echo -e "\n** EC2 Instance ${_instance_id} terminated **"
    else
      echo -e "\n** EC2 Instance ${_instance_id} not terminated **"
    fi
  fi

}

routing_table_delete() {
  declare _route_table_id="$1"
  echo -e "\n** Route Table ID ${_route_table_id} **"

  if aws ec2 describe-route-tables --route-table-ids "${_route_table_id}" --output table --no-cli-pager; then # check if route table exists
    if aws ec2 delete-route-table --route-table-id "${_route_table_id}"; then
      echo -e "\n** Route Table ${_route_table_id} deleted **"
    else
      echo -e "\n** Route Table ${_route_table_id} not deleted **"
    fi
  fi
}

gateway_remove() {
  declare _gateway_id="$1"
  declare _vpc_id="$2"
  echo -e "\n** Internet Gateway ID ${_gateway_id} **"

  if aws ec2 describe-internet-gateways --internet-gateway-ids "${_gateway_id}" --output table --no-cli-pager; then # check if gateway exists
    if aws ec2 detach-internet-gateway --internet-gateway-id "${_gateway_id}" --vpc-id "${_vpc_id}"; then
      if aws ec2 delete-internet-gateway --internet-gateway-id "${_gateway_id}"; then
        echo -e "\n** Internet Gateway ${_gateway_id} deleted **"
      else
        echo -e "\n** Internet Gateway ${_gateway_id} not deleted **"
      fi
    else
      echo -e "\n** Internet Gateway ${_gateway_id} not detached from VPC ${_vpc_id} **"
    fi
  fi
}

subnet_delete() {
  declare _subnet_id="$1"
  echo -e "\n** Subnet ID ${_subnet_id} **"

  if aws ec2 describe-subnets --subnet-ids "${_subnet_id}" --output table --no-cli-pager; then # check if subnet exists
    if aws ec2 delete-subnet --subnet-id "${_subnet_id}"; then
      echo -e "\n** Subnet ${_subnet_id} deleted **"
    else
      echo -e "\n** Subnet ${_subnet_id} not deleted **"
    fi
  fi
}

security_group_delete() {
  declare _security_group_id="$1"
  echo -e "\n** Security Group ID ${_security_group_id} **"

  if aws ec2 describe-security-groups --group-ids "${_security_group_id}" --output table --no-cli-pager; then # check if security group exists

    declare ingress_rules_json
    # All rules that refer to other security groups must be removed before the security group can be deleted
    # Get all rules and remove them
    ingress_rules_json=$(aws ec2 describe-security-groups --output json --group-ids "${_security_group_id}" --query "SecurityGroups[0].IpPermissions")
    aws ec2 revoke-security-group-ingress --group-id "${_security_group_id}" --ip-permissions "${ingress_rules_json}"

    if aws ec2 delete-security-group --group-id "${_security_group_id}"; then
      echo -e "\n** Security Group ${_security_group_id} deleted **"
    else
      echo -e "\n** Security Group ${_security_group_id} not deleted **"
    fi
  fi
}

vpc_delete() {
  declare _vpc_id="$1"
  echo -e "\n** VPC ${_vpc_id} **"

  if aws ec2 describe-vpcs --vpc-id "${_vpc_id}" --output table --no-cli-pager; then # check if VPC exists
    #Delete the VPC
    if aws ec2 delete-vpc --vpc-id "${_vpc_id}"; then
      echo -e "\n** VPC ${_vpc_id} deleted **"
    else
      echo -e "\n** VPC ${_vpc_id} not deleted **"
    fi
  fi
}

# Main script
## Needs to be run twice to delete all security groups
ec2_instance_delete "${ec2_instance_id}"
gateway_remove "${a2_gw_1_id}" "${vpc_id}"
subnet_delete "${a2_sn_web_1_id}"
subnet_delete "${a2_sn_db_1_id}"
subnet_delete "${a2_sn_db_2_id}"
routing_table_delete "${a2_web_rt_1_id}"
routing_table_delete "${a2_private_rt_1_id}"
security_group_delete "${a2_web_sg_1_id}"
security_group_delete "${a2_private_sg_1_id}"
vpc_delete "${vpc_id}"