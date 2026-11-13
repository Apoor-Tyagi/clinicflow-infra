output "instance_id" {
  description = "ID of the k3s node"
  value       = aws_instance.node.id
}

output "public_ip" {
  description = "Public IP of the k3s node"
  value       = aws_instance.node.public_ip
}

output "ssm_connect_command" {
  description = "Command to open a shell on the node without SSH"
  value       = "aws ssm start-session --target ${aws_instance.node.id} --region us-east-1"
}
