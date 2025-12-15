resource "yandex_vpc_security_group" "app_sg" {
  name        = "app-security-group"
  description = "Security group for application server"
  network_id  = local.network_id

  ingress {
    description    = "HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Spring Boot default port"
    protocol       = "TCP"
    port           = 8080
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "All outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "app" {
  name        = "app-server"
  hostname    = "app-server"
  platform_id = "standard-v2"
  zone        = local.subnet_zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 10 
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = local.subnet_id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.app_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key != null ? var.ssh_public_key : file(var.ssh_public_key_path)}"
    
    user-data = <<-EOF
      #!/bin/bash
      set -e
      export DEBIAN_FRONTEND=noninteractive
      
      # Логирование
      exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
      echo "=== Provisioning started at $(date) ===" 
      
      # Обновление системы
      echo "Updating system packages..."
      apt-get update -y
      apt-get upgrade -y
      
      # Установка Java 8 (требуется для Spring Boot приложения)
      echo "Installing Java 8..."
      apt-get install -y openjdk-8-jdk openjdk-8-jre
      JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
      update-alternatives --set java $JAVA_HOME/jre/bin/java
      update-alternatives --set javac $JAVA_HOME/bin/javac
      echo "JAVA_HOME=$JAVA_HOME" >> /etc/environment
      
      # Установка Maven (для сборки проекта)
      echo "Installing Maven..."
      apt-get install -y maven
      
      # Установка MySQL клиента (для работы с БД)
      echo "Installing MySQL client..."
      apt-get install -y mysql-client
      
      # Установка базовых инструментов
      echo "Installing basic tools..."
      apt-get install -y \
        git \
        curl \
        wget \
        unzip \
        htop \
        nano \
        net-tools \
        netcat-openbsd
      
      # Создание пользователя для приложения
      echo "Setting up application user..."
      useradd -m -s /bin/bash -d /home/dostavimvse dostavimvse || true
      
      # Создание директорий для приложения
      echo "Creating application directories..."
      mkdir -p /opt/dostavimvse/{app,logs,config}
      mkdir -p /var/log/dostavimvse
      
      # Установка прав доступа
      chown -R dostavimvse:dostavimvse /opt/dostavimvse
      chown -R dostavimvse:dostavimvse /var/log/dostavimvse
      
      # Создание systemd service файла для приложения
      cat > /etc/systemd/system/dostavimvse.service <<SVC
[Unit]
Description=DostavimVse Spring Boot Application
After=network.target

[Service]
Type=simple
User=dostavimvse
WorkingDirectory=/opt/dostavimvse/app
ExecStart=/usr/bin/java -jar /opt/dostavimvse/app/dostavimvse.jar
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dostavimvse
Environment="JAVA_HOME=$JAVA_HOME"

[Install]
WantedBy=multi-user.target
SVC
      
      # Перезагрузка systemd
      systemctl daemon-reload
      
      # Очистка
      apt-get autoremove -y
      apt-get autoclean -y
      
      echo "=== Provisioning completed successfully at $(date) ===" 
      echo "Provisioning completed at $(date)" > /var/log/provisioning-complete.log
      EOF
  }

  labels = {
    project     = "dostavimvse"
    environment = "dev"
    managed-by  = "terraform"
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

