#!/bin/bash

echo "Author: Alexander Amog"
echo "Student ID: A01263698"
echo "Set: 4C"

# define variables for CIDR and AZ
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
RDS_SUBNET_CIDR1="10.0.2.0/24"
RDS_SUBNET_CIDR2="10.0.3.0/24"

AZ="us-west-2a"
AZ1="us-west-2b"

# Create a new VPC
vpc_id=$(aws ec2 create-vpc --cidr-block "$VPC_CIDR" | yq '.Vpc.VpcId')
vpc_name="Assign2-vpc"
aws ec2 create-tags --resources "$vpc_id" --tags Key=Name,Value="$vpc_name"

aws ec2 modify-vpc-attribute --enable-dns-support --vpc-id "$vpc_id"
aws ec2 modify-vpc-attribute --enable-dns-hostnames --vpc-id "$vpc_id"

echo "DNS hostnames and DNS support enabled."
echo "VPC ID $vpc_id"

# Create a new subnet in the VPC created above
# For longer commands you can use \ to split up your command into several lines
subnet_id=$(
  aws ec2 create-subnet \
  --cidr-block "$SUBNET_CIDR" \
  --availability-zone "$AZ" \
  --vpc-id "$vpc_id" \
  | yq '.Subnet.SubnetId'
)
subnet_id1=$(
  aws ec2 create-subnet \
  --cidr-block "$RDS_SUBNET_CIDR2" \
  --availability-zone "$AZ" \
  --vpc-id "$vpc_id" \
  | yq '.Subnet.SubnetId'
)
subnet_id2=$(
  aws ec2 create-subnet \
  --cidr-block $RDS_SUBNET_CIDR1 \
  --availability-zone $AZ1 \
  --vpc-id "$vpc_id" \
  | yq '.Subnet.SubnetId'
)
echo "Subnet ID $subnet_id"
echo "Subnet ID $subnet_id1"
echo "Subnet ID $subnet_id2"

gateway_id=$(
  aws ec2 create-internet-gateway \
  --query InternetGateway.InternetGatewayId \
  --output text
)
echo "IG ID $gateway_id"

aws ec2 attach-internet-gateway --internet-gateway-id "$gateway_id" --vpc-id "$vpc_id"
echo "IGW $gateway_id attached to VPC $vpc_id"
route_table_id=$(aws ec2 create-route-table --vpc-id "$vpc_id" --query RouteTable.RouteTableId --output text)

echo "Route table ID: $route_table_id"
rt_association_id=$(aws ec2 associate-route-table --route-table-id "$route_table_id" --subnet-id "$subnet_id" --query AssociationId --output text)

echo "RT association ID: $rt_association_id"

default_cidr="0.0.0.0/0"
aws ec2 create-route --route-table-id "$route_table_id" --destination-cidr-block $default_cidr --gateway-id "$gateway_id" --output text 


security_group_name="Assign2-secGroup"

security_group_desc="SSH rule for anywhere inbound"
security_group_id=$(aws ec2 create-security-group --group-name "$security_group_name" --description "$security_group_desc" --vpc-id "$vpc_id" --query GroupId --output text)

#rds sec group
rds_security_group_name="Assign2-secGroup-rds"
rds_security_group_desc="SSH rule for anywhere inbound"
rds_security_group_id=$(aws ec2 create-security-group --group-name "$rds_security_group_name" --description "$rds_security_group_desc" --vpc-id "$vpc_id" --query GroupId --output text)

echo "Sec group ID: $security_group_id"
ip_cidr="0.0.0.0/0"

#EC2 inbound rules
aws ec2 authorize-security-group-ingress --group-id "$security_group_id" --protocol tcp --port 22 --cidr $ip_cidr --output text
aws ec2 authorize-security-group-ingress --group-id "$security_group_id" --protocol tcp --port 80 --cidr $ip_cidr --output text
aws ec2 authorize-security-group-ingress --group-id "$security_group_id" --protocol tcp --port 0-65535 --source-group "$rds_security_group_id"

echo "Authorized SSH and HTTP in inbound rule for EC2"

#RDS inbound
aws ec2 authorize-security-group-ingress --group-id "$rds_security_group_id" --protocol tcp --port 3306 --cidr $ip_cidr --output text
echo "Authorized MySQL port for RDS"

elastic_ip_allocation_id=$(aws ec2 allocate-address  --domain vpc  --query AllocationId  --output text)

elastic_ip=$(aws ec2 describe-addresses \
                          --allocation-ids "$elastic_ip_allocation_id" \
                          --query Addresses[*].PublicIp \
                          --output text)

echo "$elastic_ip"
#Force deletion of EBS disk when instances terminates - block-device-mappings
ami_id="ami-0735c191cf914754d"
instance_type="t2.micro"
key_name="assign2-key"
instance_id=$(aws ec2 run-instances \
          --image-id "$ami_id" \
          --count 1 \
          --instance-type "$instance_type" \
          --block-device-mappings "DeviceName=/dev/sda1,Ebs={DeleteOnTermination=true}" \
          --key-name "$key_name" \
          --security-group-ids "$security_group_id" \
          --subnet-id "$subnet_id" \
          --query 'Instances[*].InstanceId' \
          --output text)

echo "EC2 instance ID: $instance_id"
    while state=$(aws ec2 describe-instances \
                            --instance-ids "$instance_id" \
                            --query 'Reservations[*].Instances[*].State.Name' \
                            --output text );\
          [[ $state = "pending" ]]; do
         echo -n '.' # Show we are working on something
         sleep 3s    # Wait three seconds before checking again
    done

    echo -e "\n$instance_id: $state"
  
addr_association_id=$(aws ec2 associate-address \
                            --instance-id "$instance_id" \
                            --allocation-id "$elastic_ip_allocation_id" \
                            --query AssociationId \
                            --output text)
echo "$addr_association_id"
# Create DB subnet
echo "Association complete"
db_subnet_group_name="assign2-rds-group"
rds_subnet_group_id=$(
  aws rds create-db-subnet-group \
  --db-subnet-group-name $db_subnet_group_name \
  --db-subnet-group-description "Assignment 2 db group subnet" \
  --subnet-ids "$subnet_id1" "$subnet_id2" \
  --query DBSubnetGroup.DBSubnetGroupArn \
  --output text)

echo "$rds_subnet_group_id"

## Create an RDS Instance
rds_db_name="bookstack"
rds_instance_name="assign2-db"
rds_allocated_storage="5"
rds_instance_class="db.t2.micro"
rds_engine="mysql"
rds_master_username="bookmaster"
rds_master_user_password="Stacker123"

rds_instance_id=$(aws rds create-db-instance \
    --db-name $rds_db_name \
    --db-instance-identifier $rds_instance_name \
    --allocated-storage $rds_allocated_storage \
    --db-instance-class $rds_instance_class \
    --engine $rds_engine \
    --master-username $rds_master_username \
    --master-user-password $rds_master_user_password \
    --vpc-security-group-ids "$rds_security_group_id" \
    --db-subnet-group-name $db_subnet_group_name \
    --publicly-accessible \
    --query DBInstance.Address \
    --output text
)

echo "RDS ID $rds_instance_id"