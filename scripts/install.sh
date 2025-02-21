#!/bin/bash

# Проверка аргументов
if [ $# -eq 0 ]; then
  echo "Ошибка: Необходимо указать тип системы (stable, developer, experimental)"
  exit 1
fi

TYPE=$1
NO_CONFIRM=false
NO_INFO=false

# Обработка флагов
for arg in "$@"; do
  case $arg in
    --no-confirm) NO_CONFIRM=true ;;
    --no-info) NO_INFO=true ;;
  esac
done

# Шаг 1: Проверка типа системы
if [[ "$TYPE" != "stable" && "$TYPE" != "developer" && "$TYPE" != "experimental" ]]; then
  echo "Ошибка: Неверный тип системы. Допустимые значения: stable, developer, experimental"
  exit 1
fi

# Шаг 2: Проверка ID системы
ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
if [[ "$ID" == *"kite"* ]]; then
  echo "Ошибка: ID системы содержит 'kite'"
  exit 1
fi

# Шаг 3: Подтверждение установки
if [ "$NO_CONFIRM" = false ]; then
  read -p "Вы уверены, что хотите установить систему Kite ($TYPE)? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
  fi
fi

# Шаг 4: Скачивание и распаковка пакета
case $TYPE in
  stable)
    URL="https://github.com/kite/releases/latest/download/kite-release.tar.gz"
    ;;
  developer)
    URL="https://github.com/kite/archive/master.tar.gz"
    ;;
  experimental)
    URL="https://github.com/kite/archive/experimental.tar.gz"
    ;;
esac

TEMP_DIR=$(mktemp -d)
wget -q "$URL" -O "$TEMP_DIR/kite.tar.gz"
tar -xzf "$TEMP_DIR/kite.tar.gz" -C "$TEMP_DIR"

# Шаг 5: Копирование конфигурационных файлов
rsync -av "$TEMP_DIR/kite/config/" "$HOME/.config/"

# Шаг 6: Обновление системы и установка yay
sudo pacman -Syu --noconfirm
if ! command -v yay &> /dev/null; then
  sudo pacman -S --noconfirm yay
fi

# Шаг 7: Установка программ
yay -S --noconfirm - < "$TEMP_DIR/kite/installed-apps.lst"

# Шаг 8: Установка главной программы
# TODO: Доделать

# Шаг 9: Резервное копирование os-release
sudo cp /etc/os-release /etc/os-release.backup

# Шаг 10: Копирование файлов
sudo cp "$TEMP_DIR/kite/installed-apps.lst" /etc/
sudo cp "$TEMP_DIR/kite/os-release" /etc/

# Очистка
rm -rf "$TEMP_DIR"

