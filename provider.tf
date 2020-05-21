provider "aws" {
    alias       = "us-west-1"
    region      = "us-west-1"
}

provider "aws" {
    alias       = "eu-central-1"
    region      = "eu-central-1"
}

terraform {
    backend "s3" {
      bucket = "nick-pope-terraform-scenario-backend"
      key    = "terraform/scenario-two"
      region = "us-west-1"
    }

    required_providers{
        aws = "~> 2.7"
    }
}