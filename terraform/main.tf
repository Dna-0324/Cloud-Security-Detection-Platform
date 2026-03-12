terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "cloud-sec-vpc"
  }
}

# --- Subnet Public ---
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "cloud-sec-public-subnet"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "cloud-sec-igw"
  }
}

# --- Route Table pour Subnet Public ---
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "cloud-sec-public-rt"
  }
}

# --- Association de la Route Table au Subnet Public ---
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# --- Security Group ---
resource "aws_security_group" "ssh" {
  name        = "cloud-sec-sg"
  description = "SSH uniquement depuis mon IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH depuis mon IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["37.165.188.253/32"] # ← remplace par ton IP publique
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-sec-sg"
  }
}

# --- Elastic IP ---
resource "aws_eip" "ec2_ip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.gw]
}

# --- EC2 ---
resource "aws_instance" "web" {
  ami                         = "ami-0e2de80e7636c4837" # Amazon Linux 2023, us-west-1
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  key_name                    = "cloud-sec-key"
  vpc_security_group_ids      = [aws_security_group.ssh.id]
  associate_public_ip_address = true

  tags = {
    Name = "cloud-sec-ec2"
  }
}

# --- Association Elastic IP avec EC2 ---
resource "aws_eip_association" "ec2_eip_assoc" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.ec2_ip.id
}

# --- Bucket S3 pour CloudTrail ---
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "cloudtrail-logs-798329741052"

  tags = {
    Name = "cloudtrail-logs"
  }
}

# --- Versioning du bucket S3 ---
resource "aws_s3_bucket_versioning" "cloudtrail_logs_versioning" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# --- Chiffrement SSE du bucket S3 ---
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_sse" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Policy S3 pour CloudTrail ---
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "AWSCloudTrailListBucket"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_logs.arn
      }
    ]
  })
}

# --- CloudTrail ---
resource "aws_cloudtrail" "cloud_sec_trail" {
  name                          = "cloud-sec-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}

# --- CloudWatch Log Group ---
resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  name              = "/aws/cloudtrail/cloud-sec-trail"
  retention_in_days = 90
}

# --- IAM Role pour CloudTrail -> CloudWatch ---
resource "aws_iam_role" "cloudtrail_cloudwatch_role" {
  name = "cloudtrail-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudtrail_cloudwatch_attach" {
  role       = aws_iam_role.cloudtrail_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# --- VPC Flow Log ---
resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_cloudwatch_log_group.cloudtrail_log_group.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  iam_role_arn         = aws_iam_role.cloudtrail_cloudwatch_role.arn
}
