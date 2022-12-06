resource "aws_iam_role" "ECSrole" {
  name                = "ECSROLE"
  assume_role_policy  = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
  managed_policy_arns = [aws_iam_policy.ssmpolicy.arn,aws_iam_policy.ecs_exec.arn, "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy","arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"]
}

resource "aws_iam_policy" "ssmpolicy" {

  name = "ECS_SSM_POLICY"
  path = "/"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:Describe*",
                "ssm:Get*",
                "ssm:List*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "ecs_exec" {

  name = "ECS_exec_ssm_POLICY"
  path = "/"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}



resource "aws_security_group" "albsec-sg" {
  name   = "albsec-sg-terraform"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "ecssec-sg" {
  name   = "ECS-sg-terraform"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.albsec-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds-sg" {
  name   = "RDS-sg-terraform"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}



resource "aws_appautoscaling_target" "scaling_target" {
  max_capacity = 3
  min_capacity = 1
  resource_id = "service/${aws_ecs_cluster.clustername.name}/${aws_ecs_service.Taskservice.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}

resource "aws_appautoscaling_policy" "autoscaling_policy" {
  name               = "dev-to-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
      #resource_label = "${aws_lb.main.arn_suffix}/${aws_alb_target_group.main.arn_suffix}"
    }
    target_value  = 5
    scale_in_cooldown  = 30
    scale_out_cooldown = 30
    
  }
}



resource "aws_apigatewayv2_api" "apiname" {
  name          = "apiname"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "pythongamingproject" {
  api_id      = aws_apigatewayv2_api.apiname.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "apiname" {

  api_id             = aws_apigatewayv2_api.apiname.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  depends_on      = [aws_alb_listener.http]
  integration_uri = "http://${aws_lb.main.dns_name}/{proxy}"
}

resource "aws_apigatewayv2_route" "apiname" {
  api_id    = aws_apigatewayv2_api.apiname.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.apiname.id}"
}

