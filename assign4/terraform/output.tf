##I placed the following in this file because if it were to be in other tf files it may be hard to find the output. Additionally, it is also easier to maintain/configure.
# output public ip address of the 2 instances
output "instance_public_ips" {
  value = { for i in aws_instance.ubuntu : i.tags.Name => i.public_ip }
}
