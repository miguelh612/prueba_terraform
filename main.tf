terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.14.1"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Main VPC"
  }
}

# SUBREDES PÚBLICAS
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Subred pública 1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Subred pública 2"
  }
}

# SUBREDES PRIVADAS
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Subred privada 1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Subred privada 2"
  }
}

# INTERNET GATEWAY
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Puerta de enlace a internet"
  }
}

# EIP PARA NAT
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# NAT GATEWAY
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "Puerta de enlace NAT"
  }

  depends_on = [aws_internet_gateway.main_igw]
}

# TABLA DE ENRUTAMIENTO PÚBLICA
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "Tabla de enrutamiento pública"
  }
}

# TABLA DE ENRUTAMIENTO PRIVADA
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "Tabla de enrutamiento privada"
  }
}

# ASOCIACIÓN TABLAS DE ENRUTAMIENTO
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# S3 Bucket

resource "aws_s3_bucket" "public_bucket" {
  bucket = "imagenes-sitio-web-250920251534"

  tags = {
    Name        = "My bucket"
    Environment = "vpc"
  }
}

resource "aws_s3_bucket_public_access_block" "image_storage" {
  bucket = aws_s3_bucket.public_bucket.bucket

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# RDS

# GRUPO DE SUBREDES
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "main_group"
  subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "Grupo de subredes para base de datos"
  }
}

# SG MySQL
resource "aws_security_group" "bd_sg" {
  name        = "BD Security Group"
  description = "Permite acceso a BD MySQL"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "Public Access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Acceso MySQL"
  }
}

# Base de datos MySQL
resource "aws_db_instance" "mysql_db" {
  allocated_storage      = 10
  db_name                = "mydb"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.bd_sg.id]
  publicly_accessible    = true
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = "duoc_admin"
  password               = "contrasenasegura.2025"
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
}

# EC2 - apache

# ACCESO WEB
resource "aws_security_group" "ec2_sg" {
  name        = "Apache Security Group"
  description = "Permite acceso HTTP y SSH"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "Acceso HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Acceso SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "Acceso Apache"
  }
}

# APACHE
resource "aws_instance" "apache" {
  ami                         = "ami-0360c520857e3138f" # Ubuntu 24.04, us-east-1
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  key_name                    = "vockey"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  user_data                   = file("script/start.sh")

  tags = {
    Name = "Servidor web"
  }
}
