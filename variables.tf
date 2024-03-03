variable "gcp_project_id" {
  description = "The ID of the GCP project"
  type        = string
}

variable "project_name" {
  description = "default project name for grouping resources"
  type        = string
  default     = "scalable-iac-gcp-functions"
}

variable "default_region" {
  description = "default region for the project deployment"
  type        = string
  default     = "us-west1"
}

variable "deployment_regions" {
  description = "regions to deploy"
  type        = list(string)
  default     = ["us-central1", "us-west1", "us-east1"]
}

variable "vpc_cidr_block" {
  description = "cidr block used to create the VPC network"
  type        = string
  default     = "10.2.0.0/16"
}