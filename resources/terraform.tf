terraform {
  backend "s3" {
    encrypt = true
    bucket  = "tf-remote-state-bucket-mern-stack"
    region  = "eu-west-1"
    key     = "terraform.tfstate"
  }
}
