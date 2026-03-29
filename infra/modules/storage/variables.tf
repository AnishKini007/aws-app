variable "project" {
  type = string
}

variable "aws_account_id" {
  description = "AWS account ID used to ensure globally unique bucket names"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
