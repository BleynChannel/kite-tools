#!/bin/bash

GITHUB_USER=BleynChannel
GITHUB_REPO=Kite-Dots

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

# Функция для вывода информации
info() {
  if [ "$NO_INFO" = false ]; then
    echo "[INFO] $1"
  fi
}

# Шаг 1: Проверка типа системы
info "Проверка типа системы..."
if [[ "$TYPE" != "stable" && "$TYPE" != "developer" && "$TYPE" != "experimental" ]]; then
  echo "Ошибка: Неверный тип системы. Допустимые значения: stable, developer, experimental"
  exit 1
fi

# Шаг 2: Проверка ID системы
info "Проверка системы..."
ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
if [[ "$ID" == *"kite"* ]]; then
  echo "Ошибка: Система уже установлена!"
  exit 1
fi

# Шаг 3: Подтверждение установки
if [ "$NO_CONFIRM" = false ]; then
  read -p "Вы уверены, что хотите установить систему Kite ($TYPE)? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Установка отменена пользователем"
    exit 0
  fi
fi

# Шаг 4: Скачивание и распаковка пакета
info "Скачивание установочного пакета..."
case $TYPE in
  stable)
    info "Получение ссылки на последний стабильный релиз..."
    API_URL="https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"
    RESPONSE=$(curl -s $API_URL)
    VERSION=$(echo "$RESPONSE" | grep -oP '"tag_name": "\K[^"]+')
    if [ -z "$VERSION" ]; then
      echo "Ошибка: Не удалось получить версию релиза"
      exit 1
    fi
    URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/archive/$VERSION.tar.gz"
    if [ -z "$URL" ]; then
      echo "Ошибка: Не удалось сформировать ссылку на релиз"
      exit 1
    fi
    info "Ссылка на релиз получена: $URL"
    ;;
  developer)
    VERSION=$(git ls-remote https://github.com/$GITHUB_USER/$GITHUB_REPO.git refs/heads/master | cut -f1)
    if [ -z "$VERSION" ]; then
      echo "Ошибка: Не удалось получить хеш коммита для ветки master"
      exit 1
    fi
    URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/archive/master.tar.gz"
    ;;
  experimental)
    VERSION=$(git ls-remote https://github.com/$GITHUB_USER/$GITHUB_REPO.git refs/heads/experimental | cut -f1)
    if [ -z "$VERSION" ]; then
      echo "Ошибка: Не удалось получить хеш коммита для ветки experimental"
      exit 1
    fi
    URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/archive/experimental.tar.gz"
    ;;
esac

TEMP_DIR=$(mktemp -d)
wget -q "$URL" -O "$TEMP_DIR/kite.tar.gz"
info "Распаковка пакета..."
tar -xzf "$TEMP_DIR/kite.tar.gz" -C "$TEMP_DIR"

# Добавляем путь к распакованной папке
EXTRACTED_DIR=$(ls -d "$TEMP_DIR"/*/)
PKG_DIR=$EXTRACTED_DIR

# Шаг 5: Копирование конфигурационных файлов
info "Копирование конфигурационных файлов..."
rsync -av "$PKG_DIR/config/" "$HOME/.config/"

# Шаг 6: Обновление системы и установка yay
if [ -f /var/lib/pacman/db.lck ]; then
  echo "Ошибка: База данных pacman заблокирована. Возможно, другой процесс pacman уже запущен."
  echo "Попробуйте выполнить команду: sudo rm /var/lib/pacman/db.lck"
  exit 1
fi

info "Обновление системы..."
sudo pacman -Syu --noconfirm
if ! command -v yay &> /dev/null; then
  info "Установка yay..."
  git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay"
  (cd "$TEMP_DIR/yay" && makepkg -si --noconfirm)
fi

# Шаг 7: Установка программ
info "Установка программ из списка..."
yay -S --noconfirm - < "$PKG_DIR/installed-apps.lst"

# Шаг 8: Установка главной программы
# TODO: Доделать

# Шаг 9: Резервное копирование os-release
info "Создание резервной копии os-release..."
sudo cp /etc/os-release /etc/os-release.backup

# Шаг 10: Копирование файлов
info "Копирование системных файлов..."
sudo cp "$PKG_DIR/installed-apps.lst" /etc/
sudo cp "$PKG_DIR/os-release" /etc/

# Шаг 11: Измение BUILD_ID и VERSION_ID в os-release
info "Применение новых изменений в системе..."
sudo sed -i "s/BUILD_ID=.*$/BUILD_ID=$TYPE/" /etc/os-release
sudo sed -i "s/VERSION_ID=.*$/VERSION_ID=$VERSION/" /etc/os-release

# Очистка
info "Очистка временных файлов..."
rm -rf "$TEMP_DIR"

info "Установка системы Kite завершена успешно!"

# # Перезагрузка системы
# info "Перезагрузка системы начнется через 5 секунд..."
# sleep 5
# sudo reboot