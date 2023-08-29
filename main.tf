terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.14.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "2.11.1"
    }
  }

  required_version = ">=1.5.0"
}

provider "aws" {
  region = var.region
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

# vpc
resource "aws_vpc" "tfe" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.environment_name}-vpc"
    OwnedBy = var.owned_by
  }
}

# public subnet
resource "aws_subnet" "tfe_public" {
  vpc_id     = aws_vpc.tfe.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, 0)

  tags = {
    Name = "${var.environment_name}-subnet-public"
    OwnedBy = var.owned_by
  }
}

# private subnet
resource "aws_subnet" "tfe_private" {
  vpc_id            = aws_vpc.tfe.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = "${var.region}c"

  tags = {
    Name = "${var.environment_name}-subnet-private"
    OwnedBy = var.owned_by
  }
}

# private subnet
resource "aws_subnet" "tfe_private2" {
  vpc_id            = aws_vpc.tfe.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = "${var.region}a"

  tags = {
    Name = "${var.environment_name}-subnet-private2"
    OwnedBy = var.owned_by
  }
}

# internet gateway
resource "aws_internet_gateway" "tfe_igw" {
  vpc_id = aws_vpc.tfe.id

  tags = {
    Name = "${var.environment_name}-igw"
    OwnedBy = var.owned_by
  }
}

# add igw to default vpc route table
resource "aws_default_route_table" "tfe" {
  default_route_table_id = aws_vpc.tfe.default_route_table_id

  route {
    cidr_block = local.all_ips
    gateway_id = aws_internet_gateway.tfe_igw.id
  }

  tags = {
    Name = "${var.environment_name}-rtb"
    OwnedBy = var.owned_by
  }
}

# key pair
# RSA key of size 4096 bits
resource "tls_private_key" "rsa-4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# key pair in aws
resource "aws_key_pair" "tfe" {
  key_name   = "${var.environment_name}-keypair"
  public_key = tls_private_key.rsa-4096.public_key_openssh
}

# store private ssh key locally
resource "local_file" "tfesshkey" {
  content         = tls_private_key.rsa-4096.private_key_pem
  filename        = "${path.module}/tfesshkey.pem"
  file_permission = "0600"
}

# security group
resource "aws_security_group" "tfe_sg" {
  name   = "${var.environment_name}-sg"
  vpc_id = aws_vpc.tfe.id

  tags = {
    Name = "${var.environment_name}-sg"
    OwnedBy = var.owned_by
  }
}

# sg rule ssh inbound
resource "aws_security_group_rule" "allow_ssh_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.tfe_sg.id

  from_port   = var.ssh_port
  to_port     = var.ssh_port
  protocol    = local.tcp_protocol
  cidr_blocks = [local.all_ips]
}

# sg rule https inbound
resource "aws_security_group_rule" "allow_https_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.tfe_sg.id

  from_port   = var.https_port
  to_port     = var.https_port
  protocol    = local.tcp_protocol
  cidr_blocks = [local.all_ips]
}

# sg rule https inbound
resource "aws_security_group_rule" "allow_replicated_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.tfe_sg.id

  from_port   = var.replicated_port
  to_port     = var.replicated_port
  protocol    = local.tcp_protocol
  cidr_blocks = [local.all_ips]
}

# sg rule postgresql local vpc inbound
resource "aws_security_group_rule" "allow_postgresql_inbound_vpc" {
  type              = "ingress"
  security_group_id = aws_security_group.tfe_sg.id

  from_port   = var.postgresql_port
  to_port     = var.postgresql_port
  protocol    = local.tcp_protocol
  cidr_blocks = [aws_vpc.tfe.cidr_block]
}

# sg rule all outbound
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.tfe_sg.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = [local.all_ips]
}

# fetch ubuntu ami id for version 22.04
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

# EC2 instance
resource "aws_instance" "tfe" {
  ami                    = data.aws_ami.ubuntu.image_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.tfe.key_name
  vpc_security_group_ids = [aws_security_group.tfe_sg.id]
  subnet_id              = aws_subnet.tfe_public.id
  iam_instance_profile   = aws_iam_instance_profile.tfe_profile.name

  user_data = templatefile("${path.module}/scripts/cloud-init.tpl", {
    region              = var.region
    environment_name    = var.environment_name
    enc_password        = var.tfe_encryption_password,
    replicated_password = var.replicated_password,
    admin_username      = var.admin_username,
    admin_email         = var.admin_email,
    admin_password      = var.admin_password
    pg_password         = var.postgresql_password
    fqdn                = local.fqdn
    s3tfe               = aws_s3_bucket.tfe.bucket
    s3files             = aws_s3_bucket.tfe_files.bucket
    pg_netloc           = aws_db_instance.tfe.endpoint
    release_sequence    = var.release_sequence
  })

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "${var.environment_name}-tfe"
    OwnedBy = var.owned_by
  }

  depends_on = [
    aws_s3_bucket.tfe,
    aws_s3_bucket.tfe_files,
    aws_s3_object.replicated_license,
    aws_s3_object.certificate,
    aws_s3_object.private_key,
    aws_db_instance.tfe
  ]
}

# create public ip
resource "aws_eip" "eip_tfe" {
  domain = "vpc"
  tags = {
    Name = "${var.environment_name}-eip"
    OwnedBy = var.owned_by
  }
}

# associate public ip with instance
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.tfe.id
  allocation_id = aws_eip.eip_tfe.id
}

## route53 fqdn
# fetch zone
data "aws_route53_zone" "selected" {
  name         = var.route53_zone
  private_zone = false
}

# create record
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = local.fqdn
  type    = "A"
  ttl     = "300"
  records = [aws_eip.eip_tfe.public_ip]
}

## certficate let's encrypt
# create auth key
resource "tls_private_key" "cert_private_key" {
  algorithm = "RSA"
}

# register
resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.cert_private_key.private_key_pem
  email_address   = var.cert_email
}
# get certificate
resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.registration.account_key_pem
  common_name     = local.fqdn

  dns_challenge {
    provider = "route53"

    config = {
      AWS_HOSTED_ZONE_ID = data.aws_route53_zone.selected.zone_id
    }
  }
}

# store cert
resource "aws_acm_certificate" "cert" {
  private_key       = acme_certificate.certificate.private_key_pem
  certificate_body  = acme_certificate.certificate.certificate_pem
  certificate_chain = acme_certificate.certificate.issuer_pem
}

# s3 bucket
resource "aws_s3_bucket" "tfe_files" {
  bucket = "${var.environment_name}-filesbucket"
  force_destroy = true

  tags = {
    Name = "${var.environment_name}-filesbucket"
    OwnedBy = var.owned_by
  }
}

# disable all public bucket access
resource "aws_s3_bucket_public_access_block" "tfe_files" {
  bucket = aws_s3_bucket.tfe_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# upload license to s3 filesbucket
resource "aws_s3_object" "replicated_license" {
  bucket = aws_s3_bucket.tfe_files.bucket
  key    = "license.rli"
  source = "config/license.rli"
}

# upload certificate file to s3 filesbucket
resource "aws_s3_object" "certificate" {
  bucket  = aws_s3_bucket.tfe_files.bucket
  key     = "tfe_server.crt"
  content = "${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}"
}

# upload private key file to s3 filesbucket
resource "aws_s3_object" "private_key" {
  bucket  = aws_s3_bucket.tfe_files.bucket
  key     = "tfe_server.key"
  content = acme_certificate.certificate.private_key_pem
}

# s3 bucket
resource "aws_s3_bucket" "tfe" {
  bucket = "${var.environment_name}-bucket"
  force_destroy = true

  tags = {
    Name = "${var.environment_name}-bucket"
    OwnedBy = var.owned_by
  }
}

# disable all public bucket access
resource "aws_s3_bucket_public_access_block" "tfe" {
  bucket = aws_s3_bucket.tfe.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# instance profile
resource "aws_iam_instance_profile" "tfe_profile" {
  name = "${var.environment_name}-profile"
  role = aws_iam_role.tfe_s3_role.name
}

# iam role
resource "aws_iam_role" "tfe_s3_role" {
  name = "${var.environment_name}-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    tag-key = "${var.environment_name}-role"
    OwnedBy = var.owned_by
  }
}

# role policy
resource "aws_iam_policy" "tfe_s3_policy" {
  name = "${var.environment_name}-policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:ListStorageLensConfigurations",
          "s3:ListAccessPointsForObjectLambda",
          "s3:GetAccessPoint",
          "s3:PutAccountPublicAccessBlock",
          "s3:GetAccountPublicAccessBlock",
          "s3:ListAllMyBuckets",
          "s3:ListAccessPoints",
          "s3:PutAccessPointPublicAccessBlock",
          "s3:ListJobs",
          "s3:PutStorageLensConfiguration",
          "s3:ListMultiRegionAccessPoints",
          "s3:CreateJob"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "VisualEditor1",
        "Effect" : "Allow",
        "Action" : "s3:*",
        "Resource" : "*"
      }
    ]
  })
}

# attach policy to role
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.tfe_s3_role.name
  policy_arn = aws_iam_policy.tfe_s3_policy.arn
}

# postgresql rds
resource "aws_db_instance" "tfe" {
  identifier          = "${var.environment_name}-postgres"
  allocated_storage   = 50
  db_name             = "tfe"
  engine              = "postgres"
  engine_version      = "14.5"
  instance_class      = "db.m5.large"
  username            = "postgres"
  password            = var.postgresql_password
  skip_final_snapshot = true

  multi_az               = false
  vpc_security_group_ids = [aws_security_group.tfe_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.tfe.name

  tags = {
    Name = "${var.environment_name}-postgres"
    OwnedBy = var.owned_by
  }
}

# database subnet group
resource "aws_db_subnet_group" "tfe" {
  name       = "${var.environment_name}-subnetgroup"
  subnet_ids = [aws_subnet.tfe_private.id, aws_subnet.tfe_private2.id]

  tags = {
    Name = "${var.environment_name}-subnetgroup"
    OwnedBy = var.owned_by
  }
}