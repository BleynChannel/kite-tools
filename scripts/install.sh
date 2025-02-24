#!/bin/bash

GITHUB_USER=BleynChannel
GITHUB_REPO=Kite-Dots

# Функция для вывода справки
show_help() {
  cat <<EOF
Использование: $0 <тип_системы> [опции]

Типы системы:
  stable       - Установка стабильной версии
  developer    - Установка developer версии
  experimental - Установка экспериментальной версии

Опции:
  -h, --help     Показать эту справку
  --no-confirm   Пропустить подтверждение установки
  --no-info      Отключить информационные сообщения

Примеры:
  $0 stable
  $0 developer --no-confirm
EOF
  exit 0
}

# Проверка аргументов
if [ $# -eq 0 ]; then
  show_help
  exit 1
fi

# Обработка аргументов
TYPE=""
NO_CONFIRM=false
NO_INFO=false

for arg in "$@"; do
  case $arg in
    -h|--help)
      show_help
      ;;
    --no-confirm)
      NO_CONFIRM=true
      ;;
    --no-info)
      NO_INFO=true
      ;;
    stable|developer|experimental)
      TYPE=$arg
      ;;
    *)
      echo "Ошибка: Неизвестный аргумент '$arg'"
      show_help
      exit 1
      ;;
  esac
done

# Проверка типа системы
if [ -z "$TYPE" ]; then
  echo "Ошибка: Необходимо указать тип системы"
  show_help
  exit 1
fi

# Функция для вывода информации
info() {
  if [ "$NO_INFO" = false ]; then
    echo "[INFO] $1"
  fi
}

# Шаг 1: Проверка ID системы
info "Проверка системы..."
ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
if [[ "$ID" == *"kite"* ]]; then
  echo "Ошибка: Система уже установлена!"
  exit 1
fi

# Шаг 2: Подтверждение установки
if [ "$NO_CONFIRM" = false ]; then
  read -p "Вы уверены, что хотите установить систему Kite ($TYPE)? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Установка отменена пользователем"
    exit 0
  fi
fi

TEMP_DIR=$(mktemp -d)

# Шаг 3: Обновление системы и установка yay
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
  rm -rf "$TEMP_DIR/yay"
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

wget -q "$URL" -O "$TEMP_DIR/kite.tar.gz"
info "Распаковка пакета..."
tar -xzf "$TEMP_DIR/kite.tar.gz" -C "$TEMP_DIR"

# Добавляем путь к распакованной папке
EXTRACTED_DIR=$(ls -d "$TEMP_DIR"/*/)
PKG_DIR=$EXTRACTED_DIR

# Шаг 5: Запуск установочного скрипта
if [ "$NO_INFO" = true ]; then
  bash "$PKG_DIR/install.sh" --no-info
else
  bash "$PKG_DIR/install.sh"
fi

# Шаг 6: Резервное копирование os-release
info "Создание резервной копии os-release..."
sudo cp /etc/os-release /etc/os-release.backup

# Шаг 7: Копирование файлов
info "Копирование системных файлов..."
sudo cp "$PKG_DIR/os-release" /etc/
sudo cp "$PKG_DIR/uninstall.sh" /usr/src/kite-tools/

# Шаг 8: Измение BUILD_ID и VERSION_ID в os-release
info "Применение новых изменений в системе..."
# sudo sed -i "s/BUILD_ID=.*$/BUILD_ID=$TYPE/" /etc/os-release
sudo sed -i "s/VERSION_ID=.*$/VERSION_ID=$VERSION/" /etc/os-release

# Очистка
info "Очистка временных файлов..."
rm -rf "$TEMP_DIR"

info "Установка системы Kite завершена успешно!"

# Перезагрузка системы
# info "Перезагрузка системы начнется через 5 секунд..."
# sleep 5
# sudo reboot