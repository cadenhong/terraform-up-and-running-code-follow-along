variable "db_username" {
  description = "The username for the database"
  type = string
  sensitive = true # Indicates that this variable contains a secret; does not appear in logs or have default values
}

variable "db_password" {
  description = "The password for the database"
  type = string
  sensitive = true # Indicates that this variable contains a secret; does not appear in logs or have default values
}