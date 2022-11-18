data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name                 = "Staircaseproject"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_db_subnet_group" "subnet1" {
  name       = "publicsubnet1"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "publicsubnet1"
  }
}

resource "aws_db_subnet_group" "subnet2" {
  name       = "publicsubnet2"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "publicsubnet2"
  }
}

resource "aws_ecs_cluster" "clustername" {
  name = "Staircaseprojectcluster"
}

resource "aws_ecs_cluster_capacity_providers" "clusternameprovider" {
  cluster_name       = aws_ecs_cluster.clustername.name
  capacity_providers = ["FARGATE"]
}


resource "aws_ecs_task_definition" "staircasetask" {
  family                   = "terraformtaskplan"
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.ECSrole.arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ECSrole.arn
  container_definitions    = <<DEFINITION
[
  {
    "image": "936519216253.dkr.ecr.us-east-1.amazonaws.com/pythongamingproject:updated",
    "name": "terraformtaskplan",
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 8000
      }
    ],
    "secrets": [
            {
                "name": "host",
                "valueFrom": "Staircasedbhost"
            }
        ]
  }
]
DEFINITION
}

resource "aws_ecs_service" "Taskservice" {
  name            = "Testtaskdata"
  cluster         = aws_ecs_cluster.clustername.id
  task_definition = aws_ecs_task_definition.staircasetask.arn
  desired_count   = 1
  launch_type     = "FARGATE"



  network_configuration {
    security_groups  = [aws_security_group.ecssec-sg.id]
    subnets          = aws_db_subnet_group.subnet1.subnet_ids
    assign_public_ip = true

  }


  #depends_on = [aws_alb_listener.http]

  load_balancer {
    target_group_arn = aws_alb_target_group.main.arn
    container_name   = "terraformtaskplan"
    container_port   = 8000
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
  #depends_on      = [aws_alb_listener.http]
  integration_uri = "http://${aws_lb.main.dns_name}/{proxy}"
}

resource "aws_apigatewayv2_route" "apiname" {
  api_id    = aws_apigatewayv2_api.apiname.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.apiname.id}"
}

