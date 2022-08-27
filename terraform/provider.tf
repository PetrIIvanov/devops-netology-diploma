variable "token" {
    type        = string
    description = "This is an example input variable using env variables."
}

variable "cloud_id" {
    type        = string
    description = "This is an example input variable using env variables."
}

variable "folder_id" {
    type        = string
    description = "This is an example input variable using env variables."
}

/*
terraform {
   required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      
    }
  }
      required_version = ">= 0.13"  
}
*/ 

provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = "ru-central1-a"
}


