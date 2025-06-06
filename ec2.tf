# AMI Data Source
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Launch Template for Application Servers
resource "aws_launch_template" "app" {
  name_prefix   = "kamran-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(templatefile("${path.module}/user_data/app_userdata.sh", {
    github_repo    = var.github_repo
    pg_host        = aws_db_instance.postgresql.endpoint
    pg_database    = aws_db_instance.postgresql.db_name
    pg_user        = var.db_username
    pg_password    = var.db_password
    mysql_host     = aws_db_instance.mysql.endpoint
    mysql_database = aws_db_instance.mysql.db_name
    mysql_user     = var.db_username
    mysql_password = var.db_password
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "kamran-app-instance"
    }
  }
}

# Auto Scaling Group for Application Servers
resource "aws_autoscaling_group" "app" {
  name                = "kamran-app-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 600    # Changed from 300 (default)
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "kamran-app-asg"
    propagate_at_launch = false
  }
}

# BI Tool Instance
resource "aws_instance" "bi_tool" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[0].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(templatefile("${path.module}/user_data/bi_userdata.sh", {
    db_host     = aws_db_instance.postgresql.endpoint
    db_username = var.db_username
    db_password = var.db_password
  }))

  tags = {
    Name = "kamran-bi-tool"
  }
}