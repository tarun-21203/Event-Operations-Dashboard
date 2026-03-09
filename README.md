# Event System

A cloud-based event management system built with AWS Lambda, Step Functions, and Terraform Infrastructure as Code.

## Project Overview

This project implements a serverless event processing system that allows users to create, track, and manage events. It uses AWS Lambda functions orchestrated by Step Functions for event workflows.

## Architecture

- **Frontend:** HTML/CSS/JavaScript UI for event interaction
- **Backend:** Python Lambda functions for event processing
- **Infrastructure:** Terraform-managed AWS resources (Lambda, Step Functions, SQS, etc.)

## Project Structure

```
event_system/
├── frontend/                         # Web UI
│   ├── index.html                   # Main HTML page
│   ├── app.js                       # Frontend logic
│   ├── config.js                    # Configuration loader
│   └── style.css                    # Styling
├── lambdas/                          # AWS Lambda functions (source code)
│   ├── api_handler.py               # API gateway handler
│   ├── save_event.py                # Save event to database
│   ├── process_event.py             # Process event logic
│   ├── complete_event.py            # Mark event as complete
│   ├── archive_event.py             # Archive completed events
│   ├── notify_event.py              # Send notifications
│   ├── worker.py                    # Background worker
│   ├── requirements.txt             # Python dependencies
│   └── __init__.py
└── terraform/                        # Infrastructure as Code
    ├── main.tf                      # Main resource definitions
    ├── provider.tf                  # AWS provider configuration
    ├── variables.tf                 # Input variables
    ├── outputs.tf                   # Output values
    ├── step_function_definition.json # Step Function workflow
    ├── *.zip                        # Lambda deployment packages (required)
    └── terraform.tfstate            # State file (generated)
```
    ├── outputs.tf          # Output values
    └── step_function_definition.json  # Step Function workflow
```

## Prerequisites

- **AWS Account** with appropriate permissions (Lambda, Step Functions, SQS, DynamoDB, etc.)
- **Terraform** v1.x or higher
- **Python** 3.9+
- **AWS CLI** configured with valid credentials
- **Node.js/npm** (optional, if using npm for frontend dependencies)

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd event_system
```

### 2. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Default region, and output format
```

### 3. Deploy Infrastructure with Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Terraform will create all necessary AWS resources (Lambda functions, Step Functions, queues, etc.).

### 4. Lambda Deployment Packages

The `terraform/` folder contains pre-built Lambda function ZIP files:
- `api_handler.zip` - API Gateway request handler
- `worker.zip` - SQS message worker
- `save_event.zip` - Event persistence function
- `process_event.zip` - Event processing logic
- `notify_event.zip` - Notification sender
- `archive_event.zip` - Event archival function
- `complete_event.zip` - Event completion handler

**These ZIP files are necessary for deployment.** They are generated from the Python source code in the `lambdas/` folder and are tracked in Git to ensure consistent deployments. If you modify any Lambda function source code, you'll need to rebuild the ZIP files:

```bash
cd lambdas
# Package each Lambda function (example)
zip -j ../terraform/api_handler.zip api_handler.py
# Repeat for other functions as needed
```

Then commit and push the updated ZIP files:

```bash
git add terraform/*.zip
git commit -m "Update Lambda deployment packages"
git push origin main
```

### 5. Frontend Deployment

The frontend is a static website. You can:
- Deploy to **S3 + CloudFront** for production
- Serve locally during development using a simple HTTP server:

```bash
cd frontend
python -m http.server 8000
# or with Node.js:
npx http-server
```

Then open `http://localhost:8000` in your browser.

## API Endpoints

The system exposes REST API endpoints through API Gateway. Key endpoints:

- `POST /events` - Create a new event
- `GET /events/{id}` - Get event details
- `PUT /events/{id}` - Update an event
- `DELETE /events/{id}` - Delete an event
- `POST /events/{id}/complete` - Mark event as complete

## Workflow

1. User creates an event through the frontend
2. Event is sent to the API handler (Lambda)
3. Step Function orchestrates the event workflow:
   - Save event to database
   - Process event logic
   - Send notifications
   - Archive when complete

## Environment Variables

Create a `.env` file in the project root if needed:

```
AWS_REGION=us-east-1
API_ENDPOINT=https://your-api-gateway-url.com
```

## Development

### Adding a New Lambda Function

1. Create a new Python file in `lambdas/` (e.g., `new_function.py`)
2. Update `terraform/main.tf` to include the new function
3. Add it to the Step Function definition if part of the workflow
4. Deploy with `terraform apply`

### Local Testing

```bash
# Test a Python Lambda function locally
cd lambdas
python -m pytest  # if tests exist
python api_handler.py  # run directly
```

## Deployment

### Production Deployment

```bash
# From project root
cd terraform
terraform apply -auto-approve
```

### Destroy Resources (Caution!)

```bash
cd terraform
terraform destroy  # This will delete all AWS resources
```

## Monitoring and Logs

View Lambda logs in AWS CloudWatch:

```bash
aws logs tail /aws/lambda/<function-name> --follow
```

View Step Function executions:

```bash
aws stepfunctions list-executions --state-machine-arn <state-machine-arn>
```

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Commit changes: `git commit -m "Add your feature"`
3. Push to branch: `git push origin feature/your-feature`
4. Create a Pull Request
