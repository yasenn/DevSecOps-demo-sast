variable "yc_cloud_id" {
  type        = string
  description = "Yandex Cloud ID"
}

variable "yc_folder_id" {
  type        = string
  description = "Yandex Folder ID"
}

variable "yc_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "Default availability zone"
}

# Use one of the two auth methods:
# 1) OAuth or IAM token
# variable "yc_token" {
#   type        = string
#   description = "Yandex Cloud OAuth or IAM token"
#   sensitive   = true
# }

# 2) Service account key file (recommended)
variable "yc_sa_key_file" {
  type        = string
  default     = "key.json"
  description = "Path to service account key file"
}