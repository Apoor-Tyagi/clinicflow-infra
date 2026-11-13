terraform {
  backend "s3" {
    bucket       = "clinicflow-tfstate-016817716801-us-east-1"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
