#!/bin/bash

set -e

echo "=== SSH Auto Key Setup ==="

# ----------- Перевірки -----------
command -v ssh >/dev/null || { echo "❌ ssh не встановлено"; exit 1; }
command -v ssh-keygen >/dev/null || { echo "❌ ssh-keygen не встановлено"; exit 1; }
command -v ssh-copy-id >/dev/null || { echo "❌ ssh-copy-id не встановлено"; exit 1; }

# ----------- Дані підключення -----------
read -p "Введи IP або hostname сервера: " SERVER
read -p "Введи користувача на сервері: " USER
read -p "Порт SSH (Enter = 22): " PORT
PORT=${PORT:-22}

# ----------- Ключ -----------
DEFAULT_KEY="$HOME/.ssh/id_ed25519"

if [[ -f "$DEFAULT_KEY" ]]; then
  echo "✔ Знайдено існуючий ключ: $DEFAULT_KEY"
  read -p "Використати його? (y/n): " USE_EXISTING
else
  USE_EXISTING="n"
fi

if [[ "$USE_EXISTING" != "y" ]]; then
  echo "🔐 Створення нового SSH ключа"
  ssh-keygen -t ed25519 -f "$DEFAULT_KEY" -C "$USER@$(hostname)" -N ""
fi

# ----------- Перевірка доступу -----------
echo "🔑 Підключення до сервера (введи пароль користувача $USER)..."
ssh -p "$PORT" "$USER@$SERVER" "echo '✔ Підключення успішне'" || {
  echo "❌ Не вдалося підключитись"
  exit 1
}

# ----------- Копіювання ключа -----------
echo "📤 Копіюємо ключ на сервер..."
ssh-copy-id -i "$DEFAULT_KEY.pub" -p "$PORT" "$USER@$SERVER"

# ----------- Вимкнення паролю (опційно) -----------
read -p "Вимкнути парольну авторизацію на сервері? (y/n): " DISABLE_PASS

if [[ "$DISABLE_PASS" == "y" ]]; then
  ssh -p "$PORT" "$USER@$SERVER" << 'EOF'
sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
EOF
  echo "🔒 Парольну авторизацію вимкнено"
fi

echo ""
echo "✅ ГОТОВО"
echo "Тепер можеш підключатись так:"
echo "ssh -p $PORT $USER@$SERVER"
