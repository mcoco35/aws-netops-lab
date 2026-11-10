provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-netops-lab"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
