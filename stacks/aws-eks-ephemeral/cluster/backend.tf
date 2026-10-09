# State local: el entorno vive 72 h y se destruye con scripts/teardown-ephemeral.sh.
# El barrido por tags del teardown cubre la pérdida del state.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
