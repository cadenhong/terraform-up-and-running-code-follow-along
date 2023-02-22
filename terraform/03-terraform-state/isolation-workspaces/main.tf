provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    bucket = "terraform-up-and-running-follow-along-state"
    key = "workspaces-example/terraform.tfstate"
    region = "us-east-2"
    dynamodb_table = "terraform-up-and-running-locks"
    encrypt = true
  }
}

resource "aws_instance" "example" {
  ami = "ami-0fb653ca2d3203ac1"
  instance_type = "t2.micro"
}

## To set the default workspace's instance type as t2.medium and all others as t2.micro -
## use the following ternary syntax to conditionally set it:
# resource "aws_instance" "example" {
#   ami = "ami-0fb653ca2d3203ac1"
#   instance_type = ( terraform.workspace == "default" ? "t2.medium" : "t2.micro" )
# }