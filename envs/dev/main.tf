module "network" {
  source = "../../modules/network"

  name                = "clinicflow-dev"
  vpc_cidr            = "10.0.0.0/16"
  azs                 = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
  data_subnet_cidrs   = ["10.0.10.0/24", "10.0.11.0/24"]
}
module "security" {
  source = "../../modules/security"

  name              = "clinicflow-dev"
  environment       = "dev"
  master_secret_arn = module.database.master_secret_arn
  audit_table_arn   = module.audit_table.table_arn
}
module "compute_k3s" {
  source = "../../modules/compute-k3s"

  name                  = "clinicflow-dev"
  vpc_id                = module.network.vpc_id
  subnet_id             = module.network.public_subnet_ids[0]
  instance_profile_name = module.security.k3s_instance_profile_name
  instance_type         = "t3.small"
  architecture          = "x86_64"
  root_volume_gb        = 20
  k3s_version           = "v1.35.5+k3s1"
  argocd_version        = "v3.6.1"
  gitops_raw_url        = "https://raw.githubusercontent.com/Apoor-Tyagi/clinicflow-gitops/main"
}
module "audit_table" {
  source = "../../modules/data-dynamodb"

  name                = "clinicflow-dev-audit"
  kms_key_arn         = module.security.kms_key_arn
  deletion_protection = false
}
module "database" {
  source = "../../modules/data-rds"

  name                      = "clinicflow-dev"
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.data_subnet_ids
  allowed_security_group_id = module.compute_k3s.security_group_id
  kms_key_arn               = module.security.kms_key_arn
  engine_version            = "17.11"
  parameter_group_family    = "postgres17"
  instance_class            = "db.t4g.micro"
  allocated_storage_gb      = 20
  backup_retention_days     = 1
  multi_az                  = false
  deletion_protection       = false
}
