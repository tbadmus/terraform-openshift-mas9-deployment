cluster_name          = "ocp"
base_domain           = "sandbox.nexteramaximo.ibm.com"
openshift_pull_secret = "./openshift_pull_secret.json"
openshift_version     = "4.14.45"

# If using pre-existing VPC and subnets IDs, set the following variables
aws_vpc             = "vpc-0a8098b034e7460c0"
aws_public_subnets  = ["subnet-0893c1f7f7bbaf5fd", "subnet-0b49a47090f52df2f", "subnet-00ebe5db159d84192"]
aws_private_subnets = ["subnet-0adeb8d3806cfbd19", "subnet-05e880cf69c588fba", "subnet-00a368c54de1d62d8"]


aws_extra_tags = {
  "owner" = "admin"
}
aws_region           = var.workspace_regions[terraform.workspace]
aws_publish_strategy = "Internal"

aws_master_instance_type    = "m6a.xlarge"
aws_worker_instance_type    = "m6a.4xlarge"
aws_bootstrap_instance_type = "m6a.xlarge"

