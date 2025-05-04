
resource "local_file" "bootstrap_key_openssh" {
  content  = tls_private_key.installkey[0].public_key_openssh
  filename = "${path.root}/installer-files/bootstrap_key_openssh"
}

resource "local_file" "private_key_pem" {
  content  = tls_private_key.installkey[0].private_key_pem
  filename = "${path.root}/installer-files/private_key_pem.pem"
}