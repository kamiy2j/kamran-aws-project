variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "kamranshahid.com"
}

variable "key_name" {
  description = "AWS Key Pair name"
  type        = string
  default     = "tf_test"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "kamranuser"
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "Password123!"
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository URL"
  type        = string
  default     = "https://github.com/kamiy2j/kamran-aws-project"
}