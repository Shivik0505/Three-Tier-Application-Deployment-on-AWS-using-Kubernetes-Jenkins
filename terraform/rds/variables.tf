variable "aws_region"   { default = "ap-south-1" }
variable "db_name"      { default = "three_tier_db" }
variable "db_username"  { default = "admin" }
variable "db_password"  {
  description = "RDS master password"
  sensitive   = true
}
