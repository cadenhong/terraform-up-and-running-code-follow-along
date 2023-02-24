provider "aws" {
  region = "us-east-2"
}

terraform {
  # backend "s3" {
  #     bucket = "terraform-up-and-running-follow-along-state"
  #     region = "us-east-2"
  #     dynamodb_table = "terraform-up-and-running-locks"
  #     encrypt = true # We enabled this in the S3 bucket itself, but this is a second layer to ensure data is always encrypted
  #     key = "stage/data-stores/mysql/terraform.tfstate" # Same folder path as the web server Terraform code
  # }
}

# Resource block to create a database in RDS
resource "aws_db_instance" "example" {
  indentifier_prefix = "terraform-up-and-running"
  engine = "mysql" # Database engine
  allocated_storage = 10 # 10 GB of storage
  instance_class = "db.t2.micro" # 1 virtual CPU and 1 GB of memory
  skip_final_snapshot = true # If you don't disable the snapshot or don't provide a name using `final_snapshot_identifier`, destroy fails
  db_name = "example_database"

  username = "???"
  password = "???"
}