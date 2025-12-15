variable "yc_token" {
  description = "Yandex Cloud OAuth токен или IAM токен"
  type        = string
  sensitive   = true
}

variable "yc_folder_id" {
  description = "ID папки в Yandex Cloud"
  type        = string
}

variable "yc_cloud_id" {
  description = "ID облака в Yandex Cloud (опционально)"
  type        = string
  default     = null
}

variable "yc_zone" {
  description = "Зона Yandex Cloud (опционально)"
  type        = string
  default     = "ru-central1-b"
}

variable "existing_network_id" {
  description = "ID существующей VPC сети (если не указано, будет создана новая)"
  type        = string
  default     = null
}

variable "existing_subnet_id" {
  description = "ID существующей подсети (если не указано, будет создана новая)"
  type        = string
  default     = null
}

variable "ssh_private_key_path" {
  description = "Путь к приватному SSH ключу для доступа к серверу приложения (без passphrase!)"
  type        = string
  default     = "~/.ssh/devops"
}

variable "ssh_private_key" {
  description = "Содержимое приватного SSH ключа (альтернатива ssh_private_key_path, для использования без файла)"
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Путь к публичному SSH ключу (для добавления на сервер)"
  type        = string
  default     = "~/.ssh/devops.pub"
}

variable "ssh_public_key" {
  description = "Публичный SSH ключ (альтернатива ssh_public_key_path, если указан, используется он)"
  type        = string
  default     = null
  sensitive   = false
}

variable "db_password" {
  description = "Пароль пользователя базы данных"
  type        = string
  sensitive   = true
  default     = "sdjchdscnhsdn&77"
}

variable "mysql_public_access" {
  description = "Включить публичный доступ к MySQL (assign_public_ip = true)"
  type        = bool
  default     = true
}

variable "mysql_allowed_cidr_blocks" {
  description = "CIDR блоки для доступа к MySQL из интернета (если mysql_public_access = true). По умолчанию разрешен доступ отовсюду (0.0.0.0/0)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

