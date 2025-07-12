resource "aws_dynamodb_table" "pessoas" {
  name           = "pessoas"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

}

resource "aws_iam_role" "step_function_role" {
  name = "step_function_pessoas_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "dynamodb_access" {
  name = "step_function_dynamodb_access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Query"
      ]
      Resource = aws_dynamodb_table.pessoas.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.step_function_role.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

resource "aws_sfn_state_machine" "get_pessoa" {
  name     = "get_pessoa"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    StartAt = "GetPessoa",
    States = {
      GetPessoa = {
        Type = "Task",
        Resource = "arn:aws:states:::dynamodb:getItem",
        Parameters = {
          TableName = aws_dynamodb_table.pessoas.name
          Key = {
            id = {
              S = "$.id"
            }
          }
        },
        ResultPath = "$.dynamo_result",
        End = true
      }
    }
  })
}


//


resource "aws_api_gateway_rest_api" "pessoas_api" {
  name        = "pessoas_api"
  description = "API Gateway para pessoas"
}

resource "aws_api_gateway_resource" "pessoas_resource" {
  rest_api_id = aws_api_gateway_rest_api.pessoas_api.id
  parent_id   = aws_api_gateway_rest_api.pessoas_api.root_resource_id
  path_part   = "estudos"
}

resource "aws_api_gateway_resource" "v1_resource" {
  rest_api_id = aws_api_gateway_rest_api.pessoas_api.id
  parent_id   = aws_api_gateway_resource.pessoas_resource.id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "pessoas_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.pessoas_api.id
  parent_id   = aws_api_gateway_resource.v1_resource.id
  path_part   = "pessoas"
}

resource "aws_api_gateway_resource" "id_resource" {
  rest_api_id = aws_api_gateway_rest_api.pessoas_api.id
  parent_id   = aws_api_gateway_resource.pessoas_id_resource.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "get_pessoa" {
  rest_api_id   = aws_api_gateway_rest_api.pessoas_api.id
  resource_id   = aws_api_gateway_resource.id_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "step_function_integration" {
  rest_api_id = aws_api_gateway_rest_api.pessoas_api.id
  resource_id = aws_api_gateway_resource.id_resource.id
  http_method = aws_api_gateway_method.get_pessoa.http_method
  integration_http_method = "POST"
  type        = "AWS"
  uri         = "arn:aws:apigateway:${var.region}:states:action/StartExecution"
  credentials = aws_iam_role.step_function_role.arn

  request_templates = {
    "application/json" = <<EOF
{
  "input": "{\"id\": \"$input.params('id')\"}",
  "stateMachineArn": "${aws_sfn_state_machine.get_pessoa.arn}"
}
EOF
  }
}