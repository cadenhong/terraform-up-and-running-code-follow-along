provider "aws" {
  region = "us-east-2"
}

##### TERRAFORM BLOCK #####

# Defining a backend configuration to the Terraform block
terraform {
  backend "s3" {
    ### Since bucket, region, dynamodb_table, and encrypt will be reused, we can store this in backend.hcl
    ### Must run `terraform init -backend-config=backend.hcl`
      # bucket = "terraform-up-and-running-follow-along-state"
      # region = "us-east-2"
      # dynamodb_table = "terraform-up-and-running-locks"
      # encrypt = true # We enabled this in the S3 bucket itself, but this is a second layer to ensure data is always encrypted
    key = "global/s3/terraform.tfstate" # Filepath within the S3 bucket where the Terraform state file should be written; must be unique for every Terraform module deployed

  }
}

##### S3 BUCKET #####

# Remote backend using S3 bucket
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-up-and-running-follow-along-state"

  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = true
  }
}

# Enables versioning so every update to file creates a new version of the file (useful for reverting to older versions)
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enables server-side encryption for all data written to S3 to secure any secrets are encrypted on disk when stored in S3
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to S3
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.terraform_state.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

##### DYNAMO DB #####

# DynamoDB table used for locking - distributed key-value store that supports consistent reads and conditional writes
# The table's primary key MUST be "LockID"
resource "aws_dynamodb_table" "terraform_locks" {
  name = "terraform-up-and-running-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}