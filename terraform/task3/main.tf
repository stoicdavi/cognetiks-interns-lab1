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
