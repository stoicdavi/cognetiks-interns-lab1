# Step 3 — Create and Use Amazon ECR

## Overview

In this step you will:
- Create an Amazon ECR repository using Terraform
- Authenticate Docker to ECR
- Build, tag, and push your Docker image
- Validate the image is visible in ECR with the correct tag

---

## Prerequisites

Before starting, make sure you have:
- AWS CLI installed and configured (`aws configure`)
- Docker installed and running
- Terraform installed
- Your Docker image built from Step 2

To confirm your AWS identity:

```bash
aws sts get-caller-identity
```


---

## 3.1 — Create the ECR Repository with Terraform

Navigate to the `terraform/task3/` directory:

```bash
cd terraform/task3
```

Your `main.tf` defines the ECR repository:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_ecr_repository" "lab1_repo" {
  name                 = "lab1-app-repo"
  image_tag_mutability = "MUTABLE"

  tags = {
    environment = "dev"
  }
}

output "repository_url" {
  value = aws_ecr_repository.lab1_repo.repository_url
}

```

Initialize and apply:

```bash
terraform init
terraform apply
```

After apply completes you can obtain the repository URL with:

```bash
terraform output -raw repository_url
# or capture it in a variable
REPO_URL=$(terraform output -raw repository_url)
echo "$REPO_URL"
```

Copy this URL — you will need it in the next steps.

![terraform apply succcess](image-4.png)
---

## 3.2 — Verify the Repository in the AWS Console

1. Open the [AWS Console](https://console.aws.amazon.com)
2. Navigate to **ECR → Repositories**
3. Confirm `lab1-app-repo` is listed
![lab1-app-repo in aws management console](image.png)

---

## 3.3 — Authenticate Docker to ECR


Run the login command below (automatically obtains your AWS account ID):

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
```

You should see:

```
Login Succeeded
```
![success docker authentication into ecr](image-1.png)

---

## 3.4 — Build, Tag, and Push the Image

### Build the image

From the project root (where your `Dockerfile` is):

```bash
# build the local image
docker build -t lab1-app:latest .

# use the repo URL exported by Terraform
REPO_URL=$(cd terraform/task3 && terraform output -raw repository_url)

# tag and push (example tag v1.0.0)
docker tag lab1-app:latest ${REPO_URL}:v1.0.0
docker push ${REPO_URL}:v1.0.0
```
![successful push](image-3.png)

---

## 3.5 — Validate

### Via AWS CLI

```bash
aws ecr describe-images \
  --repository-name lab1-app-repo \
  --region us-east-1
```
![alt text](image-5.png)
You should see your image listed with `imageTag: v1.0.0`.

### Via AWS Console

1. Navigate to **ECR → Repositories → lab1-app-repo → Images**
2. Confirm the image is listed with:
   - Tag: `v1.0.0`
   - A valid image digest
   - A recent push date

![lab1-app v1.0.0](image-2.png)


---

## Summary

| Task | Status |
|---|---|
| ECR repository created via Terraform | ✅ |
| Docker authenticated to ECR | ✅ |
| Image built and tagged `v1.0.0` | ✅ |
| Image pushed to ECR | ✅ |
| Image visible in AWS Console | ✅ |
