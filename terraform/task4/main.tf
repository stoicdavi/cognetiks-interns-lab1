provider "aws" {
    region = "us-east-1"
  
}

resource "aws_vpc" "cognetiks_devops_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "cognetiks_devops"
    }
  
}

resource "aws_internet_gateway" "congentic_IGW" {
    vpc_id = aws_vpc.cognetiks_devops_vpc.id
    tags = {
        Name = "cognetiks_devops_IGW"
    }
  
}

resource "aws_subnet" "cognetiks_public_subnet_1" {
    vpc_id = aws_vpc.cognetiks_devops_vpc.id
    cidr_block = "10.0.1.0/26"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

    tags = {
        Name = "cognetiks_public_subnet_1"
    }
}

resource "aws_subnet" "cognetiks_public_subnet_2" {
    vpc_id = aws_vpc.cognetiks_devops_vpc.id
    cidr_block = "10.0.2.0/26"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true

    tags = {
        Name = "cognetiks_public_subnet_2"
    }
}

resource "aws_route_table" "cognetiks_public_route_table" {
    vpc_id = aws_vpc.cognetiks_devops_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.congentic_IGW.id
    }

    tags = {
        Name = "cognetiks_public_route_table"
    }
}

resource "aws_route_table_association" "cognetiks_public_subnet_1_association" {
    subnet_id      = aws_subnet.cognetiks_public_subnet_1.id
    route_table_id = aws_route_table.cognetiks_public_route_table.id
}

resource "aws_route_table_association" "cognetiks_public_subnet_2_association" {
    subnet_id      = aws_subnet.cognetiks_public_subnet_2.id
    route_table_id = aws_route_table.cognetiks_public_route_table.id
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
    name        = "alb_sg"
    description = "Security group for ALB"
    vpc_id      = aws_vpc.cognetiks_devops_vpc.id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# ECS Security Group
resource "aws_security_group" "ecs_sg" {
    name        = "ecs_sg"
    description = "Security group for ECS tasks"
    vpc_id      = aws_vpc.cognetiks_devops_vpc.id

    ingress {
        from_port       = 8001
        to_port         = 8001
        protocol        = "tcp"
        security_groups = [aws_security_group.alb_sg.id]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/my-app"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "main" {
  name = "app-cluster"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.cognetiks_public_subnet_1.id, aws_subnet.cognetiks_public_subnet_2.id]
}

resource "aws_lb_target_group" "app_tg" {
  name        = "app-tg"
  port        = 8001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.cognetiks_devops_vpc.id
  target_type = "ip"

  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "my-app"
    image     = "${aws_ecr_repository.lab1_repo.repository_url}:v1.0.0"
    essential = true
    portMappings = [{
      containerPort = 8001
      hostPort      = 8001
    }]
    environment = [
      { name = "INTERN_NAME",    value = "Your Full Name" },
      { name = "CLOUD_PLATFORM", value = "AWS" },
      { name = "ENVIRONMENT",    value = "dev" },
      { name = "APP_VERSION",    value = "v1.0.0" },
      { name = "APP_STATUS",     value = "healthy" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
        "awslogs-region"        = "us-east-1" # Your region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "app_service" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.cognetiks_public_subnet_1.id, aws_subnet.cognetiks_public_subnet_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true # Required so Fargate can reach ECR over the internet
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "my-app" # Must match the name in container_definitions
    container_port   = 8001
  }

  depends_on = [aws_lb_listener.http]
}

output "alb_dns_name" {
  value       = aws_lb.app_alb.dns_name
  description = "The URL of the Application Load Balancer"
}