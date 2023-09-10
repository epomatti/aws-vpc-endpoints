resource "aws_vpc_endpoint" "kms" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  tags = {
    Name = "kms-vpce"
  }
}

resource "aws_vpc_endpoint_subnet_association" "kms" {
  vpc_endpoint_id = aws_vpc_endpoint.kms.id
  subnet_id       = var.subnet_id
}

resource "aws_vpc_endpoint_security_group_association" "kms" {
  vpc_endpoint_id   = aws_vpc_endpoint.kms.id
  security_group_id = aws_security_group.kms.id
}

resource "aws_vpc_endpoint_policy" "main" {
  vpc_endpoint_id = aws_vpc_endpoint.kms.id

  policy = jsonencode({
    Statement = [{
      Action   = ["kms:*"]
      Effect   = "Allow"
      Resource = "${var.kms_key_arn}"
      Principal = {
        AWS = "${var.ec2_iam_role_arn}"
      }
    }]
  })
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_security_group" "kms" {
  name        = "vpce-kms-${var.affix}-sg"
  description = "Allow AWS Service connectivity via Interface Endpoints"
  vpc_id      = var.vpc_id

  tags = {
    Name = "sg-vpce-kms-${var.affix}"
  }
}

resource "aws_security_group_rule" "ingress_https_endpoint" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.kms.id
}

resource "aws_security_group_rule" "egress_https_endpoint" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kms.id
}
