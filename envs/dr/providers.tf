provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project    = "clinicflow"
      env        = "dr"
      managed_by = "terraform"
    }
  }
}
