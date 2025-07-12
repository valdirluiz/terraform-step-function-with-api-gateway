data "aws_caller_identity" "current" {}

data "template_file" "openapi" {
  template = file("${path.module}/open-api/open-api-v1.yml")
  vars = {
    region     = local.region
    account_id = local.account_id
  }
}