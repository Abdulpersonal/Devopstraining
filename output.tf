output "rds_id" {
  description = "Endpoint of the RDS instance"
  value       = [aws_db_instance.mydb_instance.endpoint, aws_db_instance.mydb_instance.arn]
}


output "SSM" {
  description = "Paramstore name"
  value       = aws_ssm_parameter.rdshost_address.name
}

output "VPC" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}
output "ECScluster" {
  description = "ECS Cluster"
  value       = aws_ecs_service.Taskservice.cluster
}
 output "ECSSERVICE" {
   description = "ECS"
  value       = aws_ecs_service.Taskservice.id
}
 


output "ALB" {
  description = "ALB"
  value       = aws_lb.main.dns_name
}


output "Apigateway" {
  description = "Gateway"
  value       = aws_apigatewayv2_api.apiname.api_endpoint
}

output "role" {
  description = "Role"
  value       = aws_iam_role.ECSrole.name
}

output "Securitygroup" {
  description = "SecuritygroupName"
  value = [aws_security_group.albsec-sg.id, aws_security_group.albsec-sg.name, aws_security_group.ecssec-sg.id
  , aws_security_group.ecssec-sg.name]
}


