# AMI Data Source
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Auto Scaling Group setup
resource "aws_launch_template" "app" {
  name_prefix   = "kamran-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.ec2.id]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 12
      volume_type = "gp3"
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data/app_userdata.sh", {
    github_repo    = var.github_repo
    pg_host        = split(":", aws_db_instance.postgresql.endpoint)[0]
    pg_database    = aws_db_instance.postgresql.db_name
    pg_user        = var.db_username
    pg_password    = var.db_password
    mysql_host     = split(":", aws_db_instance.mysql.endpoint)[0]
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

resource "aws_autoscaling_group" "app" {
  name                = "kamran-app-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 600
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

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "kamran-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "kamran-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# ALB Request Count Alarm
resource "aws_cloudwatch_metric_alarm" "requests_high" {
  alarm_name          = "kamran-requests-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Scale up when requests > 10 per minute per target"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    TargetGroup = aws_lb_target_group.app.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "requests_low" {
  alarm_name          = "kamran-requests-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Scale down when requests < 5 per minute per target"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    TargetGroup = aws_lb_target_group.app.arn_suffix
  }
}

# BI Tool Instance
resource "aws_instance" "bi_tool" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[0].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/user_data/bi_userdata.sh", {
    pg_host        = split(":", aws_db_instance.postgresql.endpoint)[0]
    db_username    = var.db_username
    db_password    = var.db_password
    pg_database    = aws_db_instance.postgresql.db_name
    pg_user        = var.db_username
    pg_password    = var.db_password
    mysql_host     = split(":", aws_db_instance.mysql.endpoint)[0]
    mysql_database = aws_db_instance.mysql.db_name
    mysql_user     = var.db_username
    mysql_password = var.db_password
  }))

  tags = {
    Name = "kamran-bi-tool"
  }
}