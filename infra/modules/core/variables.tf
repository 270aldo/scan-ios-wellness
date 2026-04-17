variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "artifact_repository_id" {
  type    = string
  default = "wellnesslens"
}

variable "assets_bucket_name" {
  type = string
}

variable "manage_firestore_database" {
  type    = bool
  default = false
}

variable "backend_image" {
  type    = string
  default = null
}

variable "agent_image" {
  type    = string
  default = null
}

variable "backend_service_env" {
  type    = map(string)
  default = {}
}

variable "agent_service_env" {
  type    = map(string)
  default = {}
}

variable "labels" {
  type    = map(string)
  default = {}
}
