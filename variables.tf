variable "region" {
  type        = string
  description = "The region to deploy resources in."
}

variable "environment_name" {
  type        = string
  description = "Name used to create and tag resources."
}

variable "owned_by" {
  type        = string
  description = "Used to populate the OwnedBy tag, to identify the owner."
  default     = "Terraform"
}

variable "vpc_cidr" {
  type        = string
  description = "The IP range for the VPC in CIDR format."
}

variable "ssh_port" {
  description = "Server port for SSH requests."
  type        = number
  default     = 22
}

variable "https_port" {
  description = "Server port for HTTPS requests."
  type        = number
  default     = 443
}

variable "postgresql_port" {
  description = "PostgreSQL database port."
  type        = number
  default     = 5432
}

variable "redis_port" {
  description = "Redis database port."
  type        = number
  default     = 6379
}

variable "vaultcluster_port" {
  description = "Vault cluster communication port."
  type        = number
  default     = 8201
}

variable "instance_type" {
  description = "The instance type to use for the TFE host."
  type        = string
  default     = "m5.xlarge"
}

variable "route53_zone" {
  description = "The domain used in the URL."
  type        = string
}

variable "route53_subdomain" {
  description = "the subdomain of the url"
  type        = string
}

variable "cert_email" {
  description = "Email address used to obtain ssl certificate."
  type        = string
}

variable "postgresql_password" {
  description = "PostgreSQL password."
  type        = string
}

variable "tfe_encryption_password" {
  description = "Password used to encrypt TFE data."
  type        = string
}

variable "replicated_password" {
  description = "Replicated dahsboard password."
  type        = string
}

variable "admin_username" {
  description = "Username for the TFE admin account."
  type        = string
}

variable "admin_email" {
  description = "Email address for the TFE admin account."
  type        = string
}

variable "admin_password" {
  description = "Password for the TFE admin account."
  type        = string
}

variable "release_sequence" {
  description = "Release number of the TFE version you wish to install."
  type        = number
}

variable "min_size" {
  description = "The minimum number of instances in the auto scaling group"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "The maximum number of instances in the auto scaling group"
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "The desired number of instances in the auto scaling group"
  type        = number
  default     = 1
}

variable "active_active" {
  description = "If installation type is active-active"
  type        = bool
  default     = true
}