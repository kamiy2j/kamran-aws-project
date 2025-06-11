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
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 10
    unhealthy_threshold = 3
  }

  # Deregistration delay
  deregistration_delay = 30  

  tags = {
    Name = "kamran-app-tg"
  }
}