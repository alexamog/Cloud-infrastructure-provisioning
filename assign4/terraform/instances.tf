# ec2 instances create 2 instances with different tags using for_each
## I placed the following configuration in its own file because I want to separate the ec2 instances from others. This way, it is more organized and easy to maintain/configure.
## If I need to create more instances, i could place it here.
resource "aws_instance" "ubuntu" {
  instance_type = "t2.micro"
  ami           = data.aws_ami.ubuntu.id
  for_each      = toset(["web", "app"])

  tags = {
    Name   = "ubuntu-${each.value}"
    Server = "${each.key}-server"
  }

  key_name               = aws_key_pair.local_key.id
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id              = aws_subnet.main.id

  root_block_device {
    volume_size = 10
  }
}
