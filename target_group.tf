# Target Group for Application
resource "aws_lb_target_group" "app" {
  name     = "kamran-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 15
    unhealthy_threshold = 5
  }

  tags = {
    Name = "kamran-app-tg"
  }
}