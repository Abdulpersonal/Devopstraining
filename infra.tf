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
}

resource "aws_db_subnet_group" "subnet2" {
  name       = "publicsubnet2"
  subnet_ids = module.vpc.public_subnets
}


resource "aws_db_instance" "mydb_instance" {
  allocated_storage    = 8
  db_name              = data.aws_ssm_parameter.db_name.value
  engine               = var.rds[0]
  engine_version       = var.rds[1]
  instance_class       = var.rds[2]
  username             = data.aws_ssm_parameter.db_user.value
  password             = data.aws_ssm_parameter.db_password.value
  parameter_group_name = var.rds[3]
  skip_final_snapshot  = true
  publicly_accessible = true
  identifier="staircase-app-rds"
  db_subnet_group_name = aws_db_subnet_group.subnet1.name
  vpc_security_group_ids = [aws_security_group.rds-sg.id]
}

resource "aws_ssm_parameter" "rdshost_address" {
  depends_on = [aws_db_instance.mydb_instance]
  name  = var.ssm
  type  = "String"
  value = aws_db_instance.mydb_instance.address
}

data "aws_ssm_parameter" "repo_name"{
  name="ecr_repo"
}
data "aws_ssm_parameter" "db_name"{
  name="dbname"
}
data "aws_ssm_parameter" "db_user"{
  name="dbusername"
}
data "aws_ssm_parameter" "db_password"{
  name="dbpass"
}

# data "aws_ssm_parameter" "db_username"{
#   name=""
# }

# data "aws_ssm_parameter" "db_pass"{
#   name=""
# }


resource "aws_ecs_cluster" "clustername" {
  name = "Staircaseprojectcluster"
}

resource "aws_ecs_cluster_capacity_providers" "clusternameprovider" {
  cluster_name       = aws_ecs_cluster.clustername.name
  capacity_providers = ["FARGATE"]
}


resource "aws_ecs_task_definition" "staircasetask" {
depends_on = [aws_ssm_parameter.rdshost_address]
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
    "image": "${data.aws_ssm_parameter.repo_name.value}",
    "name": "terraformtaskplan",
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 8000
      }
    ],
    "logConfiguration": {
              "logDriver": "awslogs",
              "options": {
                "awslogs-create-group": "true",
                "awslogs-group": "ecs/staircase-pythongame-group",
                "awslogs-region": "us-east-1",
                "awslogs-stream-prefix": "ecs"
              }
           },
    "secrets": [
            {
                "name": "host",
                "valueFrom": "${aws_ssm_parameter.rdshost_address.name}"
            },
            {
                "name": "dbname",
                "valueFrom": "${data.aws_ssm_parameter.db_name.name}"
            },
            {
                "name": "dbusername",
                "valueFrom": "${data.aws_ssm_parameter.db_user.name}"
            },
            {
                "name": "dbpassword",
                "valueFrom": "${data.aws_ssm_parameter.db_password.name}"
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
  enable_execute_command = true



  network_configuration {
    security_groups  = [aws_security_group.ecssec-sg.id]
    subnets          = aws_db_subnet_group.subnet1.subnet_ids
    assign_public_ip = true

  }


  depends_on = [aws_alb_listener.http]

  load_balancer {
    target_group_arn = aws_alb_target_group.main.arn
    container_name   = "terraformtaskplan"
    container_port   = 8000
  }

}

resource "aws_lb" "main" {
  name               = "staircase-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.albsec-sg.id]
  subnets            = aws_db_subnet_group.subnet1.subnet_ids

  enable_deletion_protection = false
}

resource "aws_alb_target_group" "main" {
  name        = "Staircase-alb-targetgp"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.main.arn
  }
}