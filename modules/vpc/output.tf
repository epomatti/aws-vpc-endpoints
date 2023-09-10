output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_app" {
  value = aws_subnet.app.id
}

output "subnet_vpce" {
  value = aws_subnet.vpce.id
}
