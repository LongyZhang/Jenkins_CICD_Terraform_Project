output "instance_ips" {
  description = "Public IPs of all EC2 nodes"
  value = {
    for idx, inst in aws_instance.nodes :
    local.instance_names[idx] => inst.public_ip
  }
}

output "instance_private_ips" {
  description = "PrivAte IPs of all EC2 nodes"
  value = {
    for idx, inst in aws_instance.nodes :
    local.instance_names[idx] => inst.private_ip
  }
}
