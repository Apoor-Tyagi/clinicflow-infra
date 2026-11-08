provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "clinicflow"
      env = "bootstarp"
      managed_by = "terraform"
    }
    }
  }
