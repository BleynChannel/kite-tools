#!/bin/bash 

GITHUB_USER=BleynChannel
GITHUB_REPO=Kite-Dots

# Функция для вывода справки
show_help() {
  cat <<EOF
Использование: $0 [опции]

Опции:
  -h, --help                          Показать эту справку
  -v <версия> | --version <версия>    Пропустить проверку и указать версию системы
  --no-confirm                        Пропустить подтверждение установки
  --no-info                           Отключить информационные сообщения
  --no-reboot                         Пропустить перезагрузку системы

Примеры:
  $0
  $0 -v 0.0.0 --no-confirm
EOF
  exit 0
}

# Обработка аргументов
VERSION=""
NO_CONFIRM=false
NO_INFO=false
NO_REBOOT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      ;;
    -v|--version)
      if [[ -n $2 ]]; then
        VERSION=$2
        shift
      else
        echo "Ошибка: Не указана версия после флага -v|--version"
        exit 1
      fi
      ;;
    --no-confirm)
      NO_CONFIRM=true
      ;;
    --no-info)
      NO_INFO=true
      ;;
    --no-reboot)
      NO_REBOOT=true
      ;;
    *)
      echo "Ошибка: Неизвестный аргумент '$1'"
      show_help
      exit 1
      ;;
  esac
  shift
done

# Функция для вывода информации
info() {
  if [ "$NO_INFO" = false ]; then
    echo "[INFO] $1"
  fi
}

# Шаг 1: Проверка ID системы
info "Проверка системы..."
ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
if [[ "$ID" != *"kite"* ]]; then
  echo "Ошибка: Обновление системы Kite невозможно! Установлена другая система."
  exit 1
fi

SOURCE_DIR=$(dirname "$(realpath "$0")")
TYPE=$(grep '^BUILD_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

# Шаг 2: Проверка обновления
if [ -z "$VERSION" ]; then
  info "Проверка наличия обновлений..."
  if [ -f "$SOURCE_DIR/check_update.sh" ]; then
    NEW_VERSION=$("$SOURCE_DIR/check_update.sh" -t $TYPE --no-info)
    if [ -n "$NEW_VERSION" ]; then
      info "Найдена новая версия: $NEW_VERSION"
      VERSION=$NEW_VERSION
    else
      info "Обновлений не найдено"
      exit 0
    fi
  else
    echo "Ошибка: Скрипт проверки обновлений не найден"
    exit 1
  fi
else
  info "Проверка обновлений пропущена, используется указанная версия: $VERSION"
fi

# Шаг 3: Подтверждение обновления
if [ "$NO_CONFIRM" = false ]; then
  read -p "Вы уверены, что хотите обновить систему Kite? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Установка отменена пользователем"
    exit 0
  fi
fi

# Шаг 4: Обновление пакетов
if [ -f /var/lib/pacman/db.lck ]; then
  echo "Ошибка: База данных pacman заблокирована. Возможно, другой процесс pacman уже запущен."
  echo "Попробуйте выполнить команду: sudo rm /var/lib/pacman/db.lck"
  exit 1
fi

info "Обновление пакетов..."
sudo yay -Syu --noconfirm

# Шаг 5: Скачивание и распаковка пакета
info "Скачивание установочного пакета..."
TEMP_DIR=$(mktemp -d)
case $TYPE in
  stable)
    git clone --depth 1 --branch $VERSION https://github.com/$GITHUB_USER/$GITHUB_REPO.git "$TEMP_DIR/kite"
    ;;
  developer)
    git clone --depth 1 --branch developer https://github.com/$GITHUB_USER/$GITHUB_REPO.git "$TEMP_DIR/kite"
    (cd "$TEMP_DIR/kite" && git checkout $VERSION)
    ;;
  experimental)
    git clone --depth 1 --branch experimental https://github.com/$GITHUB_USER/$GITHUB_REPO.git "$TEMP_DIR/kite"
    (cd "$TEMP_DIR/kite" && git checkout $VERSION)
    ;;
esac
PKG_DIR="$TEMP_DIR/kite"

# Инициализация и загрузка файлов через Git LFS
info "Инициализация Git LFS..."
(cd "$PKG_DIR" && git lfs install && git lfs pull)

# Шаг 6: Смена версии
if [ "$NO_INFO" = true ]; then
    info "Удаление старой версии..."
    bash "$SOURCE_DIR/uninstall.sh" full --no-confirm --no-reboot --no-info

    info "Запуск установочного скрипта..."
    bash "$PKG_DIR/install.sh" --no-info
else
    info "Удаление старой версии..."
    bash "$SOURCE_DIR/uninstall.sh" full --no-confirm --no-reboot

    info "Запуск установочного скрипта..."
    bash "$PKG_DIR/install.sh"
fi

# Шаг 7: Резервное копирование os-release
info "Создание резервной копии os-release..."
sudo cp /etc/os-release /etc/os-release.backup

# Шаг 8: Копирование файлов
info "Копирование системных файлов..."
sudo cp -f "$PKG_DIR/os-release" /etc/
sudo cp -f "$PKG_DIR/uninstall.sh" /usr/src/kite-tools/

# Шаг 9: Измение BUILD_ID и VERSION_ID в os-release
info "Применение новых изменений в системе..."
# sudo sed -i "s/BUILD_ID=.*$/BUILD_ID=$TYPE/" /etc/os-release
sudo sed -i "s/VERSION_ID=.*$/VERSION_ID=$VERSION/" /etc/os-release

# Очистка
info "Очистка временных файлов..."
rm -rf "$TEMP_DIR"

info "Обновление системы Kite завершена успешно!"

# Перезагрузка системы
if [ "$NO_REBOOT" = false ]; then
  info "Перезагрузка системы начнется через 5 секунд..."
  sleep 5
  sudo reboot
fi