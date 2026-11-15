resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids

  tags = { Name = var.name }
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "PostgreSQL: connections from the application tier only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-db" }
}

resource "aws_vpc_security_group_ingress_rule" "from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from the application security group"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = var.allowed_security_group_id
}

resource "aws_db_parameter_group" "this" {
  name   = var.name
  family = var.parameter_group_family

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_157: Multi-AZ doubles the cost; production would enable it
  #checkov:skip=CKV_AWS_118: Enhanced monitoring needs an extra IAM role and cost; dev only
  #checkov:skip=CKV_AWS_353: Performance Insights not needed for dev; enable in production
  #checkov:skip=CKV_AWS_293: Dev database is disposable; production would enable deletion protection
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage_gb
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  db_name                       = "clinicflow"
  username                      = "clinicflow_admin"
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period = var.backup_retention_days
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = !var.deletion_protection
  final_snapshot_identifier = (
    var.deletion_protection ? "${var.name}-final" : null
  )

  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true
  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
}
