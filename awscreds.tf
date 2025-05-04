## Create a map of regions for each workspace
variable "workspace_regions" {
  type = map(string)
  default = {
    sandbox        = "us-east-1"
    non-prod       = "us-east-1"
    prod-us-east-1 = "us-east-1"
    prod-us-east-2 = "us-east-2"
  }
}

provider "aws" {
  region = var.workspace_regions[terraform.workspace]
  # No credentials explicitly set here because they come from either the
  # environment or the global credentials file.
}




