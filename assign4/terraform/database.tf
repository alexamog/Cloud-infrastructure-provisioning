# create the rds instance
## I put the following configuration because I want to separate the DB instance from others. This way, it is more organized and easy to maintain/configure.
resource "aws_db_instance" "db_instance" {
  engine                 = "mysql"
  engine_version         = "8.0.31"
  multi_az               = false
  identifier             = "rds-database-instance"
  username               = "fortysix"
  password               = "password"
  instance_class         = "db.t2.micro"
  allocated_storage      = 200
  db_subnet_group_name   = aws_db_subnet_group.database_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database_security_group.id]
  availability_zone      = "us-west-2a"
  db_name                = "fortysix"
  skip_final_snapshot    = true
}
