output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.config_manager.public_ip
}

output "instance_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.config_manager.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ./config-manager.pem ubuntu@${aws_instance.config_manager.public_ip}"
}

output "ansible_inventory" {
  description = "Ansible inventory entry for this instance"
  value       = "${aws_instance.config_manager.public_dns} ansible_user=ubuntu ansible_ssh_private_key_file=./config-manager.pem"
}
