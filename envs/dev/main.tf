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
