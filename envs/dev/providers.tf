provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project    = "clinicflow"
      env        = "dev"
      managed_by = "terraform"
    }
  }
}