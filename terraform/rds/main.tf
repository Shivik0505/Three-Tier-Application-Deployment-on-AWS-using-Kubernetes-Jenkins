provider "aws" {
  region = var.aws_region
}

data "terraform_remote_state" "vpc" {
  backend = "local"
  config  = { path = "../vpc/terraform.tfstate" }
}

# ─── DB SUBNET GROUP ───────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "three-tier-db-subnet-group"
  subnet_ids = data.terraform_remote_state.vpc.outputs.db_subnets

  tags = { Name = "three-tier-db-subnet-group" }
}

# ─── RDS MySQL INSTANCE ────────────────────────────────────────────────────────
resource "aws_db_instance" "mysql" {
  identifier             = "three-tier-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp2"
  storage_encrypted      = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [data.terraform_remote_state.vpc.outputs.rds_sg_id]

  multi_az               = false   # set true for production
  publicly_accessible    = false
  deletion_protection    = false   # set true for production
  skip_final_snapshot    = true

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  tags = { Name = "three-tier-mysql" }
}

# ─── SECRETS MANAGER ───────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "rds" {
  name = "three-tier/rds-credentials"
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    host     = aws_db_instance.mysql.address
    port     = tostring(aws_db_instance.mysql.port)
    username = var.db_username
    password = var.db_password
    dbname   = var.db_name
  })
}

# ─── OUTPUTS ───────────────────────────────────────────────────────────────────
output "rds_endpoint"   { value = aws_db_instance.mysql.address }
output "rds_port"       { value = aws_db_instance.mysql.port }
output "secret_arn"     { value = aws_secretsmanager_secret.rds.arn }
