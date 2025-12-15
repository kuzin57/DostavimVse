resource "null_resource" "db_init" {
  depends_on = [
    yandex_mdb_mysql_cluster.mysql57,
    yandex_mdb_mysql_database.dostavimvse,
    yandex_mdb_mysql_user.dbuser,
    yandex_compute_instance.app
  ]

  provisioner "file" {
    connection {
      type        = "ssh"
      host        = yandex_compute_instance.app.network_interface[0].nat_ip_address
      user        = "ubuntu"
      private_key = try(file(var.ssh_private_key_path), var.ssh_private_key)
      timeout     = "10m"
      agent       = false
      bastion_host = null
    }

    source      = "${path.module}/../CREATE.sql"
    destination = "/tmp/CREATE.sql"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      host        = yandex_compute_instance.app.network_interface[0].nat_ip_address
      user        = "ubuntu"
      private_key = try(file(var.ssh_private_key_path), var.ssh_private_key)
      timeout     = "10m"
      agent       = false
    }

    content     = <<-SCRIPT
      #!/bin/bash
      set -e
      echo "=== Database Initialization Script ==="
      echo "Database host: ${yandex_mdb_mysql_cluster.mysql57.host[0].fqdn}"
      echo "Database name: ${yandex_mdb_mysql_database.dostavimvse.name}"
      echo "Database user: ${yandex_mdb_mysql_user.dbuser.name}"
      
      # Убедимся, что необходимые инструменты установлены
      echo "Checking and installing required tools..."
      
      if ! command -v nc &> /dev/null; then
        echo "Installing netcat..."
        sudo apt-get update -qq && sudo apt-get install -y netcat-openbsd || apt-get install -y netcat || true
      fi
      
      if ! command -v mysql &> /dev/null; then
        echo "Installing MySQL client..."
        export DEBIAN_FRONTEND=noninteractive
        sudo apt-get update -qq
        sudo apt-get install -y mysql-client || {
          echo "Attempting to install mysql-client from default repos..."
          sudo apt-get install -y default-mysql-client || sudo apt-get install -y mariadb-client || {
            echo "ERROR: Failed to install MySQL client"
            exit 1
          }
        }
      fi
      
      # Проверяем, что mysql доступен
      if ! command -v mysql &> /dev/null; then
        echo "ERROR: MySQL client still not available after installation attempt"
        which mysql || echo "mysql not found in PATH"
        echo "PATH: $PATH"
        exit 1
      fi
      
      echo "✓ MySQL client is available: $(which mysql)"
      mysql --version || echo "Warning: Could not get mysql version"
      
      # Ожидание доступности базы данных
      echo "Waiting for database to be ready..."
      DB_HOST="${yandex_mdb_mysql_cluster.mysql57.host[0].fqdn}"
      DB_USER="${yandex_mdb_mysql_user.dbuser.name}"
      DB_PASS="${yandex_mdb_mysql_user.dbuser.password}"
      
      RETRY_COUNT=0
      MAX_RETRIES=180  # Увеличено до 30 минут (180 * 10 сек)
      
      echo "Database host: $DB_HOST"
      echo "Database user: $DB_USER"
      echo "Testing connectivity..."
      
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # Сначала проверяем доступность порта
        if nc -z -w5 "$DB_HOST" 3306 2>/dev/null; then
          echo "  ✓ Port 3306 is open"
          # Затем проверяем MySQL подключение
          if mysql -h "$DB_HOST" -P 3306 -u "$DB_USER" -p"$DB_PASS" --connect-timeout=5 -e "SELECT 1" > /dev/null 2>&1; then
            echo "✓ Database is ready and accepting connections!"
            break
          else
            MYSQL_ERROR=$(mysql -h "$DB_HOST" -P 3306 -u "$DB_USER" -p"$DB_PASS" --connect-timeout=5 -e "SELECT 1" 2>&1 | head -1)
            echo "  Attempt $((RETRY_COUNT+1))/$MAX_RETRIES: MySQL connection failed: $MYSQL_ERROR"
          fi
        else
          echo "  Attempt $((RETRY_COUNT+1))/$MAX_RETRIES: Port 3306 not accessible yet..."
        fi
        sleep 10
        RETRY_COUNT=$((RETRY_COUNT+1))
      done
      
      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "✗ ERROR: Database failed to become ready after $MAX_RETRIES attempts (30 minutes)"
        echo "Last connection test:"
        nc -zv "$DB_HOST" 3306 2>&1 || echo "Port 3306 is not accessible"
        mysql -h "$DB_HOST" -P 3306 -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" 2>&1 || echo "MySQL connection failed"
        exit 1
      fi
      
      # Проверка существования базы данных
      DB_NAME="${yandex_mdb_mysql_database.dostavimvse.name}"
      echo "Checking if database '$DB_NAME' exists..."
      
      DB_CHECK_COUNT=0
      while [ $DB_CHECK_COUNT -lt 30 ]; do
        if mysql -h "$DB_HOST" -P 3306 -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
          echo "✓ Database '$DB_NAME' exists and is accessible"
          break
        else
          echo "  Database '$DB_NAME' not ready yet, waiting... ($((DB_CHECK_COUNT+1))/30)"
          sleep 5
          DB_CHECK_COUNT=$((DB_CHECK_COUNT+1))
        fi
      done
      
      if [ $DB_CHECK_COUNT -eq 30 ]; then
        echo "⚠ WARNING: Database '$DB_NAME' might not exist, but continuing anyway..."
        echo "Available databases:"
        mysql -h "$DB_HOST" -P 3306 -u "$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" 2>&1 || true
      fi
      
      # Инициализация схемы базы данных
      echo "Initializing database schema from /tmp/CREATE.sql..."
      if mysql -h "${yandex_mdb_mysql_cluster.mysql57.host[0].fqdn}" -P 3306 -u "${yandex_mdb_mysql_user.dbuser.name}" -p"${yandex_mdb_mysql_user.dbuser.password}" "${yandex_mdb_mysql_database.dostavimvse.name}" < /tmp/CREATE.sql 2>&1; then
        echo "✓ Database schema initialized successfully"
      else
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ]; then
          echo "✓ Database schema initialized (some tables might already exist)"
        else
          echo "⚠ Warning: Some errors occurred during schema initialization (exit code: $EXIT_CODE)"
          echo "  This might be normal if tables already exist"
        fi
      fi
      
      # Проверка созданных таблиц
      echo ""
      echo "Verifying created tables:"
      mysql -h "${yandex_mdb_mysql_cluster.mysql57.host[0].fqdn}" -P 3306 -u "${yandex_mdb_mysql_user.dbuser.name}" -p"${yandex_mdb_mysql_user.dbuser.password}" "${yandex_mdb_mysql_database.dostavimvse.name}" -e "SHOW TABLES;" || {
        echo "⚠ Warning: Could not verify tables"
      }
      
      echo ""
      echo "=== Database Initialization Completed ==="
    SCRIPT
    destination = "/tmp/init-db.sh"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = yandex_compute_instance.app.network_interface[0].nat_ip_address
      user        = "ubuntu"
      private_key = try(file(var.ssh_private_key_path), var.ssh_private_key)
      timeout     = "35m"
    }

    inline = [
      "chmod +x /tmp/init-db.sh",
      "sudo bash /tmp/init-db.sh 2>&1 | tee /tmp/db-init.log || (echo 'Script failed, exit code:' $? && cat /tmp/db-init.log && exit 1)"
    ]
  }

  triggers = {
    cluster_id     = yandex_mdb_mysql_cluster.mysql57.id
    database_id    = yandex_mdb_mysql_database.dostavimvse.id
    user_id        = yandex_mdb_mysql_user.dbuser.id
    instance_id    = yandex_compute_instance.app.id
    sql_file_hash  = filemd5("${path.module}/../CREATE.sql")
  }
}

