data "yandex_vpc_network" "existing" {
  count     = var.existing_network_id != null ? 1 : 0
  network_id = var.existing_network_id
}

resource "yandex_vpc_network" "network" {
  count = var.existing_network_id == null ? 1 : 0
  name  = "network"
}

data "yandex_vpc_subnet" "existing" {
  count     = var.existing_subnet_id != null ? 1 : 0
  subnet_id = var.existing_subnet_id
}

resource "yandex_vpc_subnet" "subnet" {
  count          = var.existing_subnet_id == null ? 1 : 0
  name           = "subnet"
  zone           = var.yc_zone
  network_id     = local.network_id
  v4_cidr_blocks = ["10.10.10.0/24"]
}

locals {
  network_id  = var.existing_network_id != null ? var.existing_network_id : yandex_vpc_network.network[0].id
  subnet_id   = var.existing_subnet_id != null ? var.existing_subnet_id : yandex_vpc_subnet.subnet[0].id
  subnet_zone = var.existing_subnet_id != null ? data.yandex_vpc_subnet.existing[0].zone : var.yc_zone
}

resource "yandex_vpc_security_group" "db_access" {
  name        = "db-access-sg"
  description = "Security group for database access from application"
  network_id  = local.network_id

  ingress {
    description       = "MySQL from app server"
    protocol          = "TCP"
    port              = 3306
    security_group_id = yandex_vpc_security_group.app_sg.id
  }

  egress {
    description    = "All outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [yandex_vpc_security_group.app_sg]
}

resource "yandex_mdb_mysql_cluster" "mysql57" {
  name                = "mysql57"
  environment         = "PRESTABLE"
  network_id          = local.network_id
  version             = "8.0"
  deletion_protection = false

  resources {
    resource_preset_id = "s2.micro"
    disk_type_id       = "network-hdd"
    disk_size          = 10
  }

  host {
    zone             = local.subnet_zone
    subnet_id        = local.subnet_id
    assign_public_ip = false
    priority         = 100
    backup_priority  = 10
  }

  security_group_ids = [yandex_vpc_security_group.db_access.id]
}

resource "yandex_mdb_mysql_database" "dostavimvse" {
  cluster_id = yandex_mdb_mysql_cluster.mysql57.id
  name       = "dostavimvse"
}

resource "yandex_mdb_mysql_user" "dbuser" {
  cluster_id = yandex_mdb_mysql_cluster.mysql57.id
  name       = "dbuser"
  password   = var.db_password
  permission {
    database_name = yandex_mdb_mysql_database.dostavimvse.name
    roles         = ["ALL"]
  }
}
