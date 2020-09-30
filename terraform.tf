terraform {
 backend “s3” {
 encrypt = true
 bucket = "terraform-remote-state-storage-s3"
 dynamodb_table = "terraform-stack-lock-dynamo"
 region = eu-west-1
 key = ./main.tf
 }
}