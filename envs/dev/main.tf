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

  name        = "clinicflow-dev"
  environment = "dev"
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
