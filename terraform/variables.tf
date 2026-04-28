variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami" {
  description = "Ubuntu 22.04 LTS AMI for eu-north-1"
  type        = string
  default     = "ami-0989fb15ce71ba39e"
}
