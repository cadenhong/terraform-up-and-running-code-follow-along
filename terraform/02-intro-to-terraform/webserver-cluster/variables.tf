# input variable to store port number
variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

# variable containing security group name
variable "server_name" {
  description = "The name of the security group"
  type        = string
  default     = "terraform-example-instance"
}