#!/bin/bash

set -e

echo "=== Настройка зеркала Terraform реестра ==="

TFRC_PATH="$HOME/.terraformrc"

if [ -f "$TFRC_PATH" ]; then
    echo "Файл $TFRC_PATH уже существует."
    read -p "Перезаписать? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Отменено"
        exit 0
    fi
fi

cat > "$TFRC_PATH" << 'EOF'
provider_installation {
  network_mirror {
    url = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
EOF

echo "✓ Файл $TFRC_PATH создан"
echo ""
echo "Теперь можно выполнить: terraform init"

