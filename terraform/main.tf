terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    dotenv = {
      source  = "jrhouston/dotenv"
      version = "~> 1.0"
    }
  }
  required_version = ">= 1.2.0"
}


data "dotenv" "config" {
  # NOTE there must be a file called `.env` in the same directory as the .tf config
  filename = ".env"
}

provider "aws" {
  region     = "us-west-2"
  access_key = data.dotenv.config.env.AWS_ACCESS_KEY_ID
  secret_key = data.dotenv.config.env.AWS_SECRET_ACCESS_KEY

}

variable "vpc_cidr" {
  description = "The default VPC cidr block"
  default     = "10.0.0.0/16"
}

#VPC
resource "aws_vpc" "acit_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "acit-4640-vpc"
  }
}

#Public subnet
resource "aws_subnet" "acit_pub_subnet" {
  vpc_id            = aws_vpc.acit_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "acit-4640-pub-sub"
  }
}

#Private subnets
resource "aws_subnet" "acit_rds_subnet1" {
  vpc_id            = aws_vpc.acit_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "acit-4640-rds-sub1"
  }
}

resource "aws_subnet" "acit_rds_subnet2" {
  vpc_id            = aws_vpc.acit_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-west-2b"
  tags = {
    Name = "acit-4640-rds-sub2"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "acit_igw" {
  vpc_id = aws_vpc.acit_vpc.id
  tags = {
    Name = "acit-4640-igw"
  }
}

#Route Table
resource "aws_route_table" "acit_rt" {
  vpc_id = aws_vpc.acit_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.acit_igw.id
  }
  tags = {
    Name = "acit-4640-rt"
  }
}

# Associate subnets with route table
resource "aws_route_table_association" "acit_rt_assoc_pub" {
  subnet_id      = aws_subnet.acit_pub_subnet.id
  route_table_id = aws_route_table.acit_rt.id
}

resource "aws_route_table_association" "acit_rt_assoc_rds1" {
  subnet_id      = aws_subnet.acit_rds_subnet1.id
  route_table_id = aws_route_table.acit_rt.id
}

resource "aws_route_table_association" "acit_rt_assoc_rds2" {
  subnet_id      = aws_subnet.acit_rds_subnet2.id
  route_table_id = aws_route_table.acit_rt.id
}

#Security Groups
resource "aws_security_group" "acit_sg_ec2" {
  name_prefix = "acit-4640-sg-ec2"
  vpc_id      = aws_vpc.acit_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "acit-4640-sg-ec2"
  }
}

resource "aws_security_group" "acit_sg_rds" {
  name_prefix = "acit-4640-sg-rds"
  vpc_id      = aws_vpc.acit_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  tags = {
    Name = "acit-4640-sg-rds"
  }

}

resource "aws_key_pair" "assign3-key" {
  key_name   = "assign3-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ec2-instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = "assign3-key"
  vpc_security_group_ids = ["${aws_security_group.acit_sg_ec2.id}"]
  subnet_id              = aws_subnet.acit_pub_subnet.id

  tags = {
    Name = "acit-4640-ec2"
  }
}

resource "aws_eip" "eip" {
  instance = aws_instance.ec2-instance.id
  vpc      = true
}

output "eip_eip" {
  description = "Elastic ip address for EC2 instance"
  value       = aws_eip.eip.*.public_ip
}


resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "rds_subnet_group"
  subnet_ids = [aws_subnet.acit_rds_subnet1.id, aws_subnet.acit_rds_subnet2.id]

  tags = {
    Name = "RDS subnet group"
  }
}

resource "aws_db_instance" "db_instance" {
  identifier             = "acit-4640-rds"
  allocated_storage      = 5
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = ["${aws_security_group.acit_sg_rds.id}"]
  db_name                = "bookstack"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t2.micro"
  username               = "bookmaster"
  password               = "Stacker123!"
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
}