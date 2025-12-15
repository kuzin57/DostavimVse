terraform {
  required_version = ">= 1.0"
  
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.95"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  folder_id = var.yc_folder_id
  cloud_id  = var.yc_cloud_id
  zone      = var.yc_zone
}

