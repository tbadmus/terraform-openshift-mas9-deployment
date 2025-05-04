terraform {
  backend "s3" {
    bucket = "elbee-tf-state-mas9"
    key    = "terraform/ent-statefile/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "elbee-tf-statefile-locks-mas9"
    encrypt = true
  }
}
