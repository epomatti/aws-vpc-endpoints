### IAM Role ###

resource "aws_iam_role" "main" {
  name = "${var.affix}-ec2"

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

resource "aws_iam_role_policy_attachment" "ssm-managed-instance-core" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

### Key Pair ###
resource "aws_key_pair" "main" {
  key_name   = "${var.affix}-keypair"
  public_key = file("${path.module}/ec2_id_rsa.pub")
}

### EC2 ###

resource "aws_network_interface" "main" {
  subnet_id       = var.subnet_id
  security_groups = [aws_security_group.main.id]

  tags = {
    Name = "ni-${var.affix}"
  }
}

resource "aws_iam_instance_profile" "main" {
  name = "${var.affix}-profile"
  role = aws_iam_role.main.id
}

resource "aws_instance" "main" {
  # Ubuntu
  ami           = var.ami
  instance_type = "t4g.nano"

  iam_instance_profile = aws_iam_instance_profile.main.id
  key_name             = aws_key_pair.main.key_name
  user_data            = file("${path.module}/user-data.sh")

  network_interface {
    network_interface_id = aws_network_interface.main.id
    device_index         = 0
  }

  tags = {
    Name = "app-${var.affix}"
  }
}


### Security Group ###
resource "aws_security_group" "main" {
  name   = "ec2-${var.affix}"
  vpc_id = var.vpc_id

  tags = {
    Name = "sg-ec2-${var.affix}"
  }
}

resource "aws_security_group_rule" "egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.main.id
}

resource "aws_security_group_rule" "egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.main.id
}
