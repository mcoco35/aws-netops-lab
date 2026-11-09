# State is local by default. Terraform writes envs/lab/terraform.tfstate, which
# is gitignored. That is intentional for a personal lab: no bucket to create
# before the first apply, and no account ID in the repository.
#
# To move state to S3, create a private versioned bucket with default
# encryption, uncomment the block below, and run:
#
#   terraform init -migrate-state
#
# use_lockfile requires Terraform >= 1.10 (the floor for this repo) and stores
# the lock in the bucket. Do not commit a real bucket name.
#
# terraform {
#   backend "s3" {
#     bucket       = "REPLACE_ME-tfstate"
#     key          = "aws-netops-lab/lab/terraform.tfstate"
#     region       = "us-east-1"
#     encrypt      = true
#     use_lockfile = true
#   }
# }
#
# DynamoDB locking is the older mechanism. Prefer use_lockfile unless you
# already operate a lock table. If you do, set dynamodb_table and omit
# use_lockfile so only one lock implementation is active.
