#!/bin/bash

cat > index.html <<EOF
<h1>Hello, World</h1>
<p>DB Address: ${db_address}</p>
<p>DB Port: ${db_port}</p>
EOF

nohup busybox httpd -f -p ${server_port} &

##### Explanation from Brikman 
## We'll be using this script with the `templatefile(<PATH>,<VARS>)` function -
## The file at PATH can use the string interpolation syntax in Terraform (${...})
## and Terraform will render the contents of that file, filling variable references from VARS

## In main.tf, it will be used as such:
  # user_data = templatefile("user-data.sh", {
  #   server_port = var.server_port
  #   db_address = data.terraform_remote_state.db.outputs.address
  #   db_port = data.terraform_remote_state.db.outputs.port
  # })