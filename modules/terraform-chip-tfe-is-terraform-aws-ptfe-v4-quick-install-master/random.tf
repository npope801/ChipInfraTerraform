resource "random_password" "enc_password" {
  length  = 24
  special = false
}

resource "random_password" "console_password" {
  length  = 16
  special = false
}

resource "random_password" "tfe_initial_admin_pw" {
  count   = var.tfe_initial_admin_pw == "" ? 1 : 0
  length  = 12
  special = false
}