provider "aws" {
  region = "ap-south-1"
}

# creating a vpc
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "my_vpc" }
}


# creating a subnet in public
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
  tags                    = { Name = "public_subnet" }
}

# creating a subnet in private two because rds requries min 2

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1a"
  tags              = { Name = "private_subnet_1" }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1b"
  tags              = { Name = "private_subnet_2" }
}


# creating a internet gateway it requires only vpcid
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags   = { Name = "igw" }
}

# creating a route tables it requrires  vpc & igm
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public_rt" }
}


# linking route table to public subnet

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# creating a security groups

resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.my_vpc.id
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
  tags = { Name = "web_sg" }
}


# creating ec2 server for the frontend

resource "aws_instance" "frontend" {
  ami                    = "ami-0c50b6f7dc3701ddd"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "alocholstore"
  user_data              = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install httpd -y
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "<h1>Welcome to my project</h1>" | sudo tee /var/www/html/index.html
              EOF
  tags                   = { Name = "frontend" }
}


# creating db for application 
resource "aws_db_instance" "postgres" {
  allocated_storage    = 20
  engine               = "postgres"
  instance_class       = "db.t3.micro"
  username             = "dbadmin"
  password             = "Bavabujji"
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  publicly_accessible  = false
  skip_final_snapshot  = true
  tags                 = { Name = "postgres_db" }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db_subnet_group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = { Name = "db_subnet_group" }
}
