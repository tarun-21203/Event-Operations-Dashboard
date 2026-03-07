data "aws_region" "current" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Public Subnets (Multi-AZ)
resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_az1
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_az2
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

# Private Subnets (Multi-AZ)
resource "aws_subnet" "private_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_az1
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_az2
  availability_zone = "us-east-1b"
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "lambda_sg" {
  name   = "lambda-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vpce_sg" {
  name   = "vpce-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DynamoDB
resource "aws_dynamodb_table" "events" {
  name         = "EventsTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "eventId"

  attribute {
    name = "eventId"
    type = "S"
  }
}

# S3 Archive
resource "random_id" "rand" {
  byte_length = 4
}

resource "aws_s3_bucket" "archive" {
  bucket        = "event-archive-${random_id.rand.hex}"
  force_destroy = true
}

# SNS
resource "aws_sns_topic" "alerts" {
  name = "event-alert-topic"
}

# SQS + DLQ
resource "aws_sqs_queue" "dlq" {
  name = "event-dlq"
}

resource "aws_sqs_queue" "main_queue" {
  name = "event-queue"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# Interface Endpoints
resource "aws_vpc_endpoint" "stepfunctions" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.states"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
  security_group_ids  = [aws_security_group.lambda_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "sns" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
  security_group_ids  = [aws_security_group.lambda_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
  security_group_ids  = [aws_security_group.lambda_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

# IAM (LabRole)
locals {
  lab_role_arn = "arn:aws:iam::036879265979:role/LabRole"
}

# Lambdas (API + Worker + Workflow)
resource "aws_lambda_function" "api" {
  function_name = "api-handler"
  role          = local.lab_role_arn
  runtime       = "python3.9"
  handler       = "api_handler.lambda_handler"
  filename      = "api_handler.zip"

  source_code_hash = filebase64sha256("api_handler.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.events.name
      QUEUE_URL  = aws_sqs_queue.main_queue.id
    }
  }
}

resource "aws_lambda_function" "worker" {
  function_name = "worker"
  role          = local.lab_role_arn
  runtime       = "python3.9"
  handler       = "worker.lambda_handler"
  filename      = "worker.zip"

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.workflow.arn
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.main_queue.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 1
}

resource "aws_lambda_function" "save" {
  function_name = "save-event"
  role          = local.lab_role_arn
  runtime       = "python3.9"
  handler       = "save_event.lambda_handler"
  filename      = "save_event.zip"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.events.name
    }
  }
}

resource "aws_lambda_function" "process" {
  function_name = "process-event"
  role          = local.lab_role_arn
  runtime       = "python3.9"
  handler       = "process_event.lambda_handler"
  filename      = "process_event.zip"

}

resource "aws_lambda_function" "notify" {
  function_name = "notify-event"
  role          = local.lab_role_arn
  runtime       = "python3.9"
  handler       = "notify_event.lambda_handler"
  filename      = "notify_event.zip"


  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

resource "aws_lambda_function" "archive" {
  function_name = "archive-event"
  role          = local.lab_role_arn
  runtime       = "python3.9"
  handler       = "archive_event.lambda_handler"
  filename      = "archive_event.zip"


  environment {
    variables = {
      ARCHIVE_BUCKET = aws_s3_bucket.archive.bucket
    }
  }
}

resource "aws_lambda_function" "complete" {
  function_name = "complete-event"
  role          = local.lab_role_arn
  runtime       = "python3.9"
  handler       = "complete_event.lambda_handler"
  filename      = "complete_event.zip"


  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.events.name
    }
  }
}

# Step Functions
resource "aws_sfn_state_machine" "workflow" {
  name     = "event-workflow"
  role_arn = local.lab_role_arn

  definition = templatefile("${path.module}/step_function_definition.json", {
    save_event_arn     = aws_lambda_function.save.arn
    process_event_arn  = aws_lambda_function.process.arn
    notify_event_arn   = aws_lambda_function.notify.arn
    archive_event_arn  = aws_lambda_function.archive.arn
    complete_event_arn = aws_lambda_function.complete.arn
  })
}

# REST API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = "event-api"
}

resource "aws_api_gateway_resource" "events" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "events"
}

resource "aws_api_gateway_resource" "event_preset" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.events.id
  path_part   = "{preset}"
}

resource "aws_api_gateway_method" "post_event" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.event_preset.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_event_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.event_preset.id
  http_method             = aws_api_gateway_method.post_event.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_method" "get_events" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.events.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_events_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.events.id
  http_method             = aws_api_gateway_method.get_events.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_resource" "analytics" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "analytics"
}

resource "aws_api_gateway_method" "get_analytics" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.analytics.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_analytics_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.analytics.id
  http_method             = aws_api_gateway_method.get_analytics.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.post_event_integration,
    aws_api_gateway_integration.get_events_integration,
    aws_api_gateway_integration.get_analytics_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}

resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
}

# WAF
resource "aws_wafv2_web_acl" "waf" {
  name  = "event-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "event-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedCommonRules"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common-rules"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "api_assoc" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.waf.arn
}

# DynamoDB Gateway Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "private_az1" {
  subnet_id      = aws_subnet.private_az1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_az2" {
  subnet_id      = aws_subnet.private_az2.id
  route_table_id = aws_route_table.private.id
}