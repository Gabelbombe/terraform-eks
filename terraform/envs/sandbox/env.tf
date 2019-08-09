# Dev environment.
# NOTE: If environment copied, change environment related values (e.g. "sandbox" -> "prod").

##### Terraform configuration #####

# Usage:
# AWS_PROFILE=tmv-test terraform init (only first time)
# AWS_PROFILE=tmv-test terraform get
# AWS_PROFILE=tmv-test terraform plan
# AWS_PROFILE=tmv-test terraform apply

# NOTE: You have to create backend S3 bucket and DynamoDB with LockID primary manually before creating new env!
terraform {
  required_version = ">=0.11.10"

  backend "s3" {
    bucket = "gabelbombe-sandbox-terraform-backend" # NOTE: S3 is regional: always add the same identifying prefix to your S3 buckets!
    key    = "gabelbombe-sandbox-terraform.tfstate"

    # Ireland.
    region         = "eu-west-1"
    dynamodb_table = "gabelbombe-sandbox-terraform-backend-table" # NOTE: You have to create this DynamoDB manually with LockID primary key.

    # profile        = "GEHC-077"                                   # NOTE: This is AWS account profile, not env! You probably have two accounts: one sandbox (or test) and one prod.
  }
}

provider "aws" {
  region = "eu-west-1"
}

# Here we inject our values to the environment definition module which creates all actual resources.
module "env-def" {
  source = "../../modules/env-def"
  prefix = "gabelbombe"
  env    = "sandbox"

  # Ireland
  region = "eu-west-1"
}
