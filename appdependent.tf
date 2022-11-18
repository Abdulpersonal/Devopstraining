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
  managed_policy_arns = [aws_iam_policy.ssmpolicy.arn, "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
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

