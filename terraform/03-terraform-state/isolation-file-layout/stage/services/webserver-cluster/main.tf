provider "aws" {
  region = "us-east-2"
}

terraform {
  # backend "s3" {
  #     bucket = "terraform-up-and-running-follow-along-state"
  #     region = "us-east-2"
  #     dynamodb_table = "terraform-up-and-running-locks"
  #     encrypt = true # We enabled this in the S3 bucket itself, but this is a second layer to ensure data is always encrypted
  #     key = "stage/services/webserver-cluster/terraform.tfstate" # Same folder path as the web server Terraform code
  # }
}

# Security Group for EC2 created
resource "aws_security_group" "instance" {
  name = var.server_name

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##### AUTO SCALING GROUP #####
### Instead of having one EC2, we will have a cluster of EC2s using Auto Scaling Group

# Launch configuration to specify how to configure each EC2 in an Auto Scaling Group
resource "aws_launch_configuration" "example" {
  image_id        = "ami-0fb653ca2d3203ac1" # Equivalent to aws_instance.example.ami
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id] # Equivalent to aws_instance.example.vpc_security_group_ids

  ## Original User Data Script:
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  ## User Data with terraform_remote_state data source:
  # user_data = <<EOF
  #             #!/bin/bash
  #             echo "Hello, World" >> index.html
  #             echo "${data.terraform_remote_state.db.outputs.address}" >> index.html
  #             echo "${data.terraform_remote_state.db.outputs.port}" >> index.html
  #             nohup busybox httpd -f -p ${var.server_port} &
  #             EOF

  ## User Data using the `templatefile` function and passing variables it needs to map:
  # user_data = templatefile("user-data.sh", {
  #   server_port = var.server_port
  #   db_address  = data.terraform_remote_state.db.outputs.address
  #   db_port     = data.terraform_remote_state.db.outputs.port
  # })

  lifecycle {
    create_before_destroy = true # Required when using launch configuration with ASG for replacement EC2 to be made before destroying old ones
  }
}

# Auto Scaling Group resource
resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnets.default.ids # Specifies which VPC subnets the EC2 should be deployed to; pulls subnet ids out of aws_subnets data source and tells ASG to use those subnets

  target_group_arns = [aws_lb_target_group.asg.arn] # ALB target group attached
  health_check_type = "ELB" # Default is EC2, but doing ELB will give a more robust health check; will also instruct ASG to replace an EC2 if it's down or serving requests due to memory outage or process crash

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

##### DATA SOURCES #####
### Read-only info fetched from the provider (e.g. AWS); does not create anything new
### Just queries provider's API for data to make it available to rest of the Terraform code

# Data source to look up data for my default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source to look up subnets within default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

## Data source to look up outputs from the database's state file -
## It will configure the webserver cluster code to read the state file from the
## same S3 bucket and folder where the database stores its state
## Retrieve information using `data.terraform_remote_state.<NAME>.outputs.<ATTRIBUTE>`
# data "terraform_remote_state" "db" {
#   backend = "s3"

#   config = {
#     bucket = "terraform-up-and-running-follow-along-state"
#     key = "stage/data-stores/mysql/terraform.tfstate"
#     region = "us-east-2"
#   }
# }

##### APPLICATION LOAD BALANCER #####
### To distribute traffic across servers and give all users the IP (or DNS name) of the ALB
### Consists of a listener, listener rule, and target group

# Create an Application Load Balancer (ALB)
resource "aws_lb" "example" {
  name = "terraform-asg-example"
  load_balancer_type = "application"
  subnets = data.aws_subnets.default.ids
  security_groups  = [aws_security_group.alb.id]
}

# Listener -> To specify port (e.g. 80) and protocol (e.g. HTTP) to listen on
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port = 80
  protocol = "HTTP"

  # Return a simple 404 page as default response for requests that don't match any listener rules
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = 404
    }
  }
}

# Security Group for ALB to allow incoming requests on port 80 so people can access the ALB over HTTP and allow outgoing requests on all ports so the ALB can perform health checks
resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

  # Allow inbount HTTP requests
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Target Group -> one or more servers that receives requests from the ALB
# Also performs health checks and sends requests only to healthy nodes
# Attach this to the aws_autoscaling_group resource by pointing target_group_arns to this
resource "aws_lb_target_group" "asg" {
  name = "terraform-asg-example"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  # This TG will health check the EC2s by periodically sending an HTTP request to
  # each instance and will consider the instance "healthy" only if it returns a
  # response that matches the configured "matcher"; if it is marked "unhealthy",
  # the TG will automatically stop sending traffic to it to minimize disruptions for users
  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200" # Must match this for an EC2 to be considered healthy
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

# Listener Rule -> Takes requests that come into a listener and sends those that match specific paths or hostnames to target groups
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
    path_pattern {
      values = ["*"] # To match any path to the target group that contains the ASG
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}