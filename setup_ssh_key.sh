#!/bin/bash

set -e

echo "=== SSH Key Setup Script ==="

# Перевірка root
if [[ $EUID -ne 0 ]]; then
  echo "❌ Запусти скрипт від root"
  exit 1
fi

# Запит користувача
read -p "Введи ім'я користувача: " USERNAME

if id "$USERNAME" &>/dev/null; then
  echo "✔ Користувач існує"
else
  read -p "Користувача не існує. Створити? (y/n): " CREATE_USER
  if [[ "$CREATE_USER" == "y" ]]; then
    useradd -m -s /bin/bash "$USERNAME"
    echo "✔ Користувача створено"
  else
    echo "❌ Вихід"
    exit 1
  fi
fi

USER_HOME=$(eval echo "~$USERNAME")
SSH_DIR="$USER_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown "$USERNAME:$USERNAME" "$SSH_DIR"

echo ""
echo "Як хочеш додати ключ?"
echo "1) Вставити вручну"
echo "2) Взяти з файлу"
read -p "Обери (1/2): " KEY_MODE

if [[ "$KEY_MODE" == "1" ]]; then
  echo "Встав public key (ssh-ed25519 / ssh-rsa...) і натисни Enter:"
  read PUBKEY
elif [[ "$KEY_MODE" == "2" ]]; then
  read -p "Шлях до public key файлу: " KEYFILE
  if [[ ! -f "$KEYFILE" ]]; then
    echo "❌ Файл не знайдено"
    exit 1
  fi
  PUBKEY=$(cat "$KEYFILE")
else
  echo "❌ Невірний вибір"
  exit 1
fi

echo "$PUBKEY" >> "$AUTH_KEYS"

chmod 600 "$AUTH_KEYS"
chown "$USERNAME:$USERNAME" "$AUTH_KEYS"

echo "✔ Ключ додано"

# Пропозиція вимкнути парольну авторизацію
read -p "Вимкнути парольну авторизацію SSH? (y/n): " DISABLE_PASS

if [[ "$DISABLE_PASS" == "y" ]]; then
  SSHD_CONFIG="/etc/ssh/sshd_config"

  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD_CONFIG"
  sed -i 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
  sed -i 's/^#\?UsePAM .*/UsePAM no/' "$SSHD_CONFIG"

  systemctl restart sshd
  echo "✔ Парольну авторизацію вимкнено"
fi

echo ""
echo "✅ Готово. Можеш підключатись:"
echo "ssh $USERNAME@<server_ip>"
