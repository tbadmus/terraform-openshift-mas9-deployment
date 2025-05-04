cluster_name          = "ocp"
base_domain           = "sandbox.ashabilimited.com"
openshift_pull_secret = "./openshift_pull_secret.json"
openshift_version     = "4.14.45"

# If using pre-existing VPC and subnets IDs, set the following variables
aws_vpc             = "vpc-086ce02e5fcdaf195"
aws_public_subnets  = ["subnet-0fb1fe715519b4a00", "subnet-04515965b4c6e9a00", "subnet-064c32c70e6906bef"]
aws_private_subnets = ["subnet-0d3fa07504f0ae1d3", "subnet-0d13678e8d106a024", "subnet-02307951d2d536225"]

aws_extra_tags = {
  "owner" = "admin"
}
aws_region           = var.workspace_regions[terraform.workspace]
aws_publish_strategy = "Internal"

aws_master_instance_type    = "m6a.xlarge"
aws_worker_instance_type    = "m6a.4xlarge"
aws_bootstrap_instance_type = "m6a.xlarge"

