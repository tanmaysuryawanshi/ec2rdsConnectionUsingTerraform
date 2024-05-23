provider "aws" {
  region = "us-east-1"
}


resource "aws_vpc" "my_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "EC2-to-RDS-VPC"
    } 
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  availability_zone = "us-east-1a"
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Private Subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1c"
  tags = {
    Name = "Private Subnet-2"
  }
}
resource "aws_internet_gateway" "ig_2tier" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "Internet Gateway for EC2-to-RDS VPC"
  }
}

#public route table with internet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "Public route_table"
  }
}

#public subnet associated with the subnet
resource "aws_route_table_association" "public-route-table-association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

#routing internet to public subnet
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"  # This is the default route for internet-bound traffic
  gateway_id             = aws_internet_gateway.ig_2tier.id
}


#private route table without internet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "private route_table"
  }
}



#private subnet associated with the subnet
resource "aws_route_table_association" "private-route-table-association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private-route-table-association-2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}
resource "aws_key_pair" "ssh-key" {
  key_name = "ssh-key"
  public_key = "" #public key to be put here
}
#creating ec2 instance
resource "aws_instance" "ec2" {
    ami = "ami-0bb84b8ffd87024d8"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.public_subnet.id
    associate_public_ip_address = true
    key_name = "ssh-key"
    tags = {
        Name = "EC2-for-RDS"
    }
    security_groups = [ aws_security_group.sg_for_ec2.id ]
}

resource "aws_security_group" "sg_for_ec2" {
  name        = "allow_ssh"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]  #if multi AZ add another subnet
}

resource "aws_security_group" "sg_for_rds" {
  name        = "my-db-sg"
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port   = 3306  # MySQL port
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.sg_for_ec2.id]
  }
}

resource "aws_db_instance" "my_db_instance" {
  allocated_storage    = 10
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  db_name              = "dbdatabase"
  username             = "admin"
  password             = "password"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name

    # Attach the DB security group
  vpc_security_group_ids = [aws_security_group.sg_for_rds.id]  
    tags = {
        Name = "ec2_to_mysql_rds"
    }
}


