locals {
  region     = var.region
  account_id = data.aws_caller_identity.current.account_id
}