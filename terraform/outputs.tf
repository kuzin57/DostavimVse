output "app_instance_ip" {
  description = "Публичный IP адрес сервера приложения"
  value       = yandex_compute_instance.app.network_interface[0].nat_ip_address
}

output "app_instance_internal_ip" {
  description = "Внутренний IP адрес сервера приложения"
  value       = yandex_compute_instance.app.network_interface[0].ip_address
}

output "app_instance_id" {
  description = "ID Compute Instance сервера приложения"
  value       = yandex_compute_instance.app.id
}

output "app_instance_fqdn" {
  description = "FQDN сервера приложения"
  value       = yandex_compute_instance.app.fqdn
}

output "mysql_cluster_id" {
  description = "ID Managed MySQL кластера"
  value       = yandex_mdb_mysql_cluster.mysql57.id
}

output "mysql_fqdn" {
  description = "FQDN Managed MySQL базы данных"
  value       = yandex_mdb_mysql_cluster.mysql57.host[0].fqdn
}

output "mysql_database_name" {
  description = "Имя базы данных"
  value       = yandex_mdb_mysql_database.dostavimvse.name
}

output "mysql_username" {
  description = "Имя пользователя базы данных"
  value       = yandex_mdb_mysql_user.dbuser.name
  sensitive   = false
}

output "database_url" {
  description = "JDBC URL для подключения к базе данных"
  value       = "jdbc:mysql://${yandex_mdb_mysql_cluster.mysql57.host[0].fqdn}:3306/${yandex_mdb_mysql_database.dostavimvse.name}?useSSL=false"
  sensitive   = true
}

output "ssh_connection_command" {
  description = "Команда для SSH подключения к серверу"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${yandex_compute_instance.app.network_interface[0].nat_ip_address}"
}

output "mysql_connection_info" {
  description = "Информация для подключения к MySQL"
  value = {
    fqdn          = yandex_mdb_mysql_cluster.mysql57.host[0].fqdn
    database      = yandex_mdb_mysql_database.dostavimvse.name
    username      = yandex_mdb_mysql_user.dbuser.name
    port          = 3306
    public_access = var.mysql_public_access
  }
}

output "mysql_connection_string" {
  description = "Строка подключения к MySQL (команда mysql)"
  value       = "mysql -h ${yandex_mdb_mysql_cluster.mysql57.host[0].fqdn} -P 3306 -u ${yandex_mdb_mysql_user.dbuser.name} -p ${yandex_mdb_mysql_database.dostavimvse.name}"
  sensitive   = false
}

output "application_config" {
  description = "Конфигурация для application.properties"
  value = {
    datasource_url      = "jdbc:mysql://${yandex_mdb_mysql_cluster.mysql57.host[0].fqdn}:3306/${yandex_mdb_mysql_database.dostavimvse.name}?useSSL=false"
    datasource_username = yandex_mdb_mysql_user.dbuser.name
    datasource_password = "Используйте пароль из yandex_mdb_mysql_user.dbuser"
  }
  sensitive = true
}

