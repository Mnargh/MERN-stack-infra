variable "region" {
  description = "This is the cloud hosting region where your webapp will be deployed."
}

variable "env_prefix" {
  description = "This is the environment where your webapp is deployed"
}

variable "MONGODB_ACCESS" {
  description = "Establishes connection to access to mongodb atlas"
  default     = ""
}

variable "MONGODB_GROUP_ID" {
  description = "MongoDB Group ID required for whitelisting AWS instance to mongodb atlas"
  default     = ""
}

variable "MONGODB_PUBLIC_API_KEY" {
  description = "MongoDB public api key required for whitelisting AWS instance to mongodb atlas"
  default     = ""
}

variable "MONGODB_SECRET_API_KEY" {
  description = "MongoDB secret api key required for whitelisting AWS instance to mongodb atlas"
  default     = ""
}

variable "JWT_SECRET" {
  description = "Json web token secret to be passed to application container"
  default     = ""
}
variable "GITHUB_CLIENT_ID" {
  description = "Github client id to be passed to application container"
  default     = ""
}
variable "GITHUB_SECRET" {
  description = "Github secret to be passed to application container"
  default     = ""
}
