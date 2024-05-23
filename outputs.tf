
output "rds-endpoint" {
    value = aws_db_instance.my_db_instance.endpoint
}

output "ec2-publicip"{
    value = aws_instance.ec2.public_ip
}

output "public_key" {
    value = aws_key_pair.ssh-key
  
}