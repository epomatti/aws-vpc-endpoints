provider "aws" {
  region = local.region
}

### Locals ###

data "aws_caller_identity" "current" {}

locals {
  account_id        = data.aws_caller_identity.current.account_id
  region            = "sa-east-1"
  affix             = "pe-sandbox"
  INADDR_ANY        = "0.0.0.0/0"
  availability_zone = "sa-east-1a"
}

### VPC ###
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  # Enable DNS hostnames 
  enable_dns_hostnames = true

  tags = {
    Name = local.affix
  }
}

### Internet Gateway ###

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${local.affix}"
  }
}

### Route Tables ###

resource "aws_default_route_table" "internet" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = local.INADDR_ANY
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "internet-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # !!! NAT Gateway route will be added later

  tags = {
    Name = "private-rt"
  }
}

### Subnets ###

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = local.availability_zone

  # Auto-assign public IPv4 address
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.affix}-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.90.0/24"
  availability_zone = local.availability_zone

  tags = {
    Name = "${local.affix}-subnet"
  }
}

# Assign the private route table to the private subnet
resource "aws_route_table_association" "private_subnet" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

### NAT Gateway ###
# This will allow the private instance to connect to the internet

resource "aws_eip" "nat_gateway" {
  vpc = true
}

resource "aws_nat_gateway" "public" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "nat-internet"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.main]
}

resource "aws_route" "nat_gateway" {
  route_table_id         = aws_route_table.private.id
  nat_gateway_id         = aws_nat_gateway.public.id
  destination_cidr_block = "0.0.0.0/0"
}

### Security Group ###

# This will clean up all default entries
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group_rule" "egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_default_security_group.default.id
}

resource "aws_security_group_rule" "egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_default_security_group.default.id
}

### IAM Role ###

resource "aws_iam_role" "main" {
  name = local.affix

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm-managed-instance-core" {
  role       = aws_iam_role.main.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

### Key Pair ###
resource "aws_key_pair" "deployer" {
  key_name   = "mysql-server-key"
  public_key = file("${path.module}/id_rsa.pub")
}

### EC2 ###

resource "aws_network_interface" "main" {
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_default_security_group.default.id]

  tags = {
    Name = "ni-${local.affix}"
  }
}

resource "aws_iam_instance_profile" "main" {
  name = "${local.affix}-profile"
  role = aws_iam_role.main.id
}

resource "aws_instance" "main" {
  # Ubuntu
  ami           = "ami-08ae71fd7f1449df1"
  instance_type = "t3.medium"

  iam_instance_profile = aws_iam_instance_profile.main.id
  key_name             = aws_key_pair.deployer.key_name
  user_data            = file("${path.module}/user-data.sh")

  # Detailed monitoring enabled
  monitoring = true

  network_interface {
    network_interface_id = aws_network_interface.main.id
    device_index         = 0
  }

  tags = {
    Name = "${local.affix}"
  }
}

### SQS Interface VPC Endpoint ###

resource "aws_security_group" "aws_service" {
  name        = "AllowAWSServiceConnectivity"
  description = "Allow AWS Service connectivity via Interface Endpoints"
  vpc_id      = aws_vpc.main.id

  # ingress {
  #   description = "TLS from VPC"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = [aws_vpc.main.cidr_block]
  # }

  # egress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
}

resource "aws_sqs_queue" "private_queue" {
  name = "my-private-queue"
}

resource "aws_sqs_queue_policy" "allow_ec2_role" {
  queue_url = aws_sqs_queue.private_queue.url
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "sqspolicy"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = [aws_iam_role.main.arn]
      }
      Action   = ["sqs:SendMessage"]
      Resource = aws_sqs_queue.private_queue.arn
    }]
  })
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.sqs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
}

resource "aws_vpc_endpoint_subnet_association" "private_subnet" {
  vpc_endpoint_id = aws_vpc_endpoint.sqs.id
  subnet_id       = aws_subnet.private.id
}

resource "aws_vpc_endpoint_security_group_association" "sg_ec2" {
  vpc_endpoint_id   = aws_vpc_endpoint.sqs.id
  security_group_id = aws_security_group.aws_service.id
}

resource "aws_vpc_endpoint_policy" "main" {
  vpc_endpoint_id = aws_vpc_endpoint.sqs.id
  # policy = jsonencode({
  #   Statement = [{
  #     Action   = ["sqs:SendMessage"]
  #     Effect   = "Allow"
  #     Resource = aws_sqs_queue.private_queue-arn
  #     Principal = {
  #       AWS = aws_iam_role.main.arn
  #     }
  #   }]
  # })
  # policy = jsonencode({
  #   Statement = [{
  #     Action   = ["sqs:SendMessage"]
  #     Effect   = "Allow"
  #     Resource = "*"
  #     Principal = {
  #       AWS = "*"
  #     }
  #   }]
  # })
}

### Output ###

output "sqs_queue_url" {
  value = aws_sqs_queue.private_queue.url
}

output "aws_cli_enqueue_command" {
  value = "aws sqs send-message --queue-url ${aws_sqs_queue.private_queue.url} --message-body 'Hello'"
}
