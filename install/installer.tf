resource "null_resource" "openshift_installer" {
  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = <<-EOT
      mkdir -p ${path.root}/installer-files
      case $(uname -s) in
        Linux)
          wget -q -O ${path.root}/installer-files/openshift-install-linux.tar.gz https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.openshift_version}/openshift-install-linux-${var.openshift_version}.tar.gz || { echo 'Download failed'; exit 1; }
          ;;
        Darwin)
          wget -q -O ${path.root}/installer-files/openshift-install-mac.tar.gz https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.openshift_version}/openshift-install-mac-${var.openshift_version}.tar.gz || { echo 'Download failed'; exit 1; }
          ;;
        *) exit 1
          ;;
      esac
    EOT
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "tar zxvf ${path.root}/installer-files/openshift-install-*.tar.gz -C ${path.root}/installer-files/"
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "rm -f ${path.root}/installer-files/openshift-install-*.tar.gz ${path.root}/installer-files/robots*.txt* ${path.root}/installer-files/README.md"
  }
}

resource "null_resource" "openshift_client" {
  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = <<EOF
      case $(uname -s) in
        Linux)
          wget -q -O ${path.root}/installer-files/openshift-client-linux.tar.gz https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.openshift_version}/openshift-client-linux-${var.openshift_version}.tar.gz || { echo 'Download failed'; exit 1; }
          ;;
        Darwin)
          wget -q -O ${path.root}/installer-files/openshift-client-mac.tar.gz https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.openshift_version}/openshift-client-mac-${var.openshift_version}.tar.gz || { echo 'Download failed'; exit 1; }
          ;;
        *) exit 1
          ;;
      esac
EOF
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "tar zxvf ${path.root}/installer-files/openshift-client-*.tar.gz -C ${path.root}/installer-files/"
  }

  provisioner "local-exec" {
    command = "rm -f ${path.root}/installer-files/openshift-client-*.tar.gz ${path.root}/installer-files/robots*.txt* ${path.root}/installer-files/README.md"
  }
}

resource "null_resource" "generate_manifests" {
  triggers = {
    install_config = data.template_file.install_config_yaml.rendered
  }

  depends_on = [
    local_file.install_config,
    # null_resource.aws_credentials,
    null_resource.openshift_installer,
  ]

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "rm -rf ${path.root}/installer-files/temp"
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "mkdir -p ${path.root}/installer-files/temp"
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "mv ${path.root}/installer-files/install-config.yaml ${path.root}/installer-files/temp"
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "${path.root}/installer-files/openshift-install --dir=${path.root}/installer-files/temp create manifests"

  }
}

# because we're providing our own control plane machines, remove it from the installer
resource "null_resource" "manifest_cleanup_control_plane_machineset" {
  triggers = {
    install_config = data.template_file.install_config_yaml.rendered
    local_file     = local_file.install_config.id
  }

  depends_on = [
    null_resource.generate_manifests
  ]

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "rm -f ${path.root}/installer-files/temp/openshift/99_openshift-cluster-api_master-machines-*.yaml ${path.root}/installer-files/temp/openshift/99_openshift-machine-api_master-control-plane-machine-set.yaml"
  }
}

# build the bootstrap ignition config
resource "null_resource" "generate_ignition_config" {
  triggers = {
    install_config            = data.template_file.install_config_yaml.rendered
    local_file_install_config = local_file.install_config.id
  }

  depends_on = [
    null_resource.manifest_cleanup_control_plane_machineset,
    local_file.airgapped_registry_upgrades,
    local_file.create_worker_machineset,
    local_file.airgapped_registry_upgrades,
    local_file.cluster-dns-02-config,
    local_file.create_infra_machineset,
    local_file.cluster-monitoring-configmap,
    local_file.configure-image-registry-job-serviceaccount,
    local_file.configure-image-registry-job-clusterrole,
    local_file.configure-image-registry-job-clusterrolebinding,
    local_file.configure-image-registry-job,
    local_file.configure-ingress-job-serviceaccount,
    local_file.configure-ingress-job-clusterrole,
    local_file.configure-ingress-job-clusterrolebinding,
    local_file.configure-ingress-job,
  ]

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "mkdir -p ${path.root}/installer-files/temp"
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "rm -rf ${path.root}/installer-files/temp/_manifests ${path.root}/installer-files/temp/_openshift"
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "cp -r ${path.root}/installer-files/temp/manifests ${path.root}/installer-files/temp/_manifests"
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "cp -r ${path.root}/installer-files/temp/openshift ${path.root}/installer-files/temp/_openshift"
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    command = "${path.root}/installer-files/openshift-install --dir=${path.root}/installer-files/temp create ignition-configs"
  }
}

resource "null_resource" "delete_aws_resources" {

  depends_on = [
    null_resource.cleanup
  ]

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    when    = destroy
    command = "${path.root}/install/aws_cleanup.sh"
    #command = "${path.root}/installer-files/openshift-install --dir=${path.root}/installer-files/temp destroy cluster"
  }

}

resource "null_resource" "cleanup" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    when    = destroy
    command = "rm -rf ${path.root}/installer-files/temp"
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    when    = destroy
    command = "rm -f ${path.root}/installer-files/openshift-install"
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    when    = destroy
    command = "rm -f ${path.root}/installer-files/oc"
  }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    when    = destroy
    command = "rm -f ${path.root}/installer-files/kubectl"
  }
}

data "local_file" "bootstrap_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename = "${path.root}/installer-files/temp/bootstrap.ign"
}

data "local_file" "master_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename = "${path.root}/installer-files/temp/master.ign"
}

data "local_file" "worker_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename = "${path.root}/installer-files/temp/worker.ign"
}

resource "null_resource" "get_auth_config" {
  depends_on = [null_resource.generate_ignition_config]
  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    when    = create
    command = "cp ${path.root}/installer-files/temp/auth/* ${path.root}"
  }
  provisioner "local-exec" {
    environment = {
      LC_ALL = "C"
    }
    when    = destroy
    command = "if [ -f ${path.root}/kubeconfig ]; then rm ${path.root}/kubeconfig; fi; if [ -f ${path.root}/kubeadmin-password ]; then rm ${path.root}/kubeadmin-password; fi"
  }
}

# Create the secret in AWS Secrets Manager (need to do this in a null_resource because the file isn't created until the ignition config is generated)
resource "null_resource" "create_secret" {
  provisioner "local-exec" {
    command = <<EOT
aws secretsmanager create-secret \
  --name "${var.clustername}-${var.terraform_workspace}-openshift-secret" \
  --secret-string '{"kubeconfig":"'"$(cat ${path.root}/kubeconfig | sed ':a;N;$!ba;s/\n/\\n/g')"'","kubeadmin-password":"'"$(cat ${path.root}/kubeadmin-password | sed 's/\\/\\\\/g')"'"}'
EOT
  }
  provisioner "local-exec" {
    when    = destroy
    command = "aws secretsmanager delete-secret --force-delete-without-recovery --secret-id ${self.triggers.secret_id} --force-delete-without-recovery"
  }
  triggers = {
    secret_id = "${var.clustername}-${var.terraform_workspace}-openshift-secret"
  }
  depends_on = [null_resource.get_auth_config]
}

# Create the secret policy in AWS Secrets Manager for the secret
resource "null_resource" "apply_secret_policy" {
  provisioner "local-exec" {
    command = <<EOT
aws secretsmanager put-resource-policy \
  --secret-id "${var.clustername}-${var.terraform_workspace}-openshift-secret" \
  --resource-policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": [
            "${data.aws_caller_identity.current.arn}",
            "${tolist(data.aws_iam_roles.administrator_roles.arns)[0]}"
          ]
        },
        "Action": "secretsmanager:*",
        "Resource": "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.clustername}-${var.terraform_workspace}-openshift-secret"
      }
    ]
  }'
EOT
  }
  provisioner "local-exec" {
    when    = destroy
    command = "aws secretsmanager delete-resource-policy --secret-id ${self.triggers.secret_id}"
  }
  triggers = {
    secret_id = "${var.clustername}-${var.terraform_workspace}-openshift-secret"
  }
  depends_on = [null_resource.create_secret]
}

# Needed to get the user you are running the installer with
data "aws_caller_identity" "current" {}

# Needed to get the ARN of the AWSReservedSSO_AWSAdministratorAccess_ (AFT generated role) role arn
data "aws_iam_roles" "administrator_roles" {
  name_regex  = "AWSReservedSSO_AWSAdministratorAccess_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

# resource "aws_secretsmanager_secret" "openshift_secret" {
#   name                    = "${data.local_file.infrastructureID.content}-openshift-secret"
#   description             = "Kubeadmin password and Kubeconfig for ${data.local_file.infrastructureID.content}"
#   recovery_window_in_days = 0

#  tags = var.tags
#}

#resource "aws_secretsmanager_secret_version" "openshift_secret_version" {
#  secret_id = aws_secretsmanager_secret.openshift_secret.id
#  secret_string = jsonencode({
#    "kubeadmin_password" = file("${path.root}/kubeadmin-password"),
#    "kubeconfig" = file("${path.root}/kubeconfig")
#  })

#  depends_on = [
#    null_resource.generate_ignition_config
#  ]
#}

#data "aws_caller_identity" "current" {}

#data "aws_iam_roles" "administrator_roles" {
#  name_regex  = "AWSReservedSSO_AWSAdministratorAccess_.*"
#  path_prefix = "/aws-reserved/sso.amazonaws.com/"
#}
#resource "aws_secretsmanager_secret_policy" "openshift_secret_policy" {
#  secret_arn = aws_secretsmanager_secret.openshift_secret.arn

#  policy = jsonencode({
#    "Version": "2012-10-17",
#    "Statement": [
#      {
#        "Effect": "Allow",
#        "Principal": {
#          "AWS": [
#            "${data.aws_caller_identity.current.arn}",
#            "${tolist(data.aws_iam_roles.administrator_roles.arns)[0]}"
#          ]
#        },
#        "Action": "secretsmanager:*",
#        "Resource": "${aws_secretsmanager_secret.openshift_secret.arn}"
#      }
#    ]
#  })

#  depends_on = [
#    aws_secretsmanager_secret.openshift_secret
#  ]
#}
