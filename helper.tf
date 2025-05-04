locals {
  major_version = join(".", slice(split(".", var.openshift_version), 0, 2))
  aws_azs       = (var.aws_azs != null) ? var.aws_azs : tolist([join("", [var.workspace_regions[terraform.workspace], "a"]), join("", [var.workspace_regions[terraform.workspace], "b"]), join("", [var.workspace_regions[terraform.workspace], "c"])])
  rhcos_image_url = "https://raw.githubusercontent.com/openshift/installer/release-${local.major_version}/data/data/coreos/rhcos.json"
}

// Use Terraform's http data source to fetch the RHCOS image JSON
data "http" "rhcos_image_json" {
  url = local.rhcos_image_url
}

// Process the metadata to extract relevant information
locals {

  # Parse the JSON to extract the RHCOS image ID for the specified region
  rhcos_image = jsondecode(data.http.rhcos_image_json.response_body).architectures.x86_64.images.aws.regions[var.workspace_regions[terraform.workspace]].image
}

output "rhcos_ami_name" {
  value = local.rhcos_image
}

# Data source to find the RHCOS AMI

# Get the IPAM pool for the AWS region and account
# data "aws_vpc_ipam_pool" "pool" {
#   filter {
#     name   = "locale"
#     values = [var.workspace_regions[terraform.workspace]]
#   }
# }

# Get aws partition
data "aws_partition" "current" {}
