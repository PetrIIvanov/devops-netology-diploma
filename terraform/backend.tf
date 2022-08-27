terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }

  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "netology-devops"
    region     = "ru-central1"
    key        = "diploma/diploma_terraform.tfstate"
    access_key = "YCAJE_ruWxOUF3AAbRJuAC30e"
    secret_key = "YCPUOaquCjVs2PfjGtcHyzSMZCDWgAyAAN8FGoJ4"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
	required_version = ">= 0.13"
}
