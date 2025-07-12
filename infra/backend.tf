terraform {
  backend "s3" {
    bucket         = "terraform-state-step-function-with-api-gateway"
    key            = "sns-and-sqs/infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
  }
}