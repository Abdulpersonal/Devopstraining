variable "rds" {
  description = "Value of the Name RDS instance"
  type        = list(string)
  default     = [ "mysql", "5.7", "db.t2.micro", "default.mysql5.7"]
}


variable "ssm" {
  description = "Name of SSM"
  type        = string
  default     = "Staircasedbhost"
  
}