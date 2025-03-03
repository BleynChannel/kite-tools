#!/bin/bash

# Флаг для отключения вывода информации
GITHUB_USER=BleynChannel
GITHUB_REPO=Kite-Dots

# Функция для вывода справки
show_help() {
  cat <<EOF
Использование: $0 [опции]

Опции:
  -h, --help     Показать эту справку
  -t, --type     Тип системы (stable, developer, experimental)
  --no-info      Отключить информационные сообщения

Примеры:
  $0
  $0 -t stable --no-info
EOF
  exit 0
}

# Обработка аргументов
TYPE=""
NO_INFO=false

# Функция для вывода информации
info() {
  if [ "$NO_INFO" = false ]; then
    echo "[INFO] $1"
  fi
}

get_system_version() {
    if [ -f /etc/os-release ]; then
        VERSION_ID=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
        echo $VERSION_ID
    fi
}

check_github_commit() {
    BRANCH=$1
    CURRENT_COMMIT=$2

    # Получаем последний коммит из репозитория с учетом ветки
    LATEST_COMMIT=$(git ls-remote https://github.com/$GITHUB_USER/$GITHUB_REPO.git refs/heads/$BRANCH 2>/dev/null | awk '{print $1}')

    # Проверяем успешность выполнения команды
    if [ $? -ne 0 ]; then
        echo "Error: Не удалось получить данные из репозитория" >&2
        echo "Unknown"
        return 1
    fi

    # Проверяем, что коммит получен
    if [ -z "$LATEST_COMMIT" ]; then
        echo "Error: Ветка $BRANCH не найдена" >&2
        echo "Unknown"
        return 1
    fi

    # Сравниваем коммиты
    if [ "$LATEST_COMMIT" != "$CURRENT_COMMIT" ]; then
        echo $LATEST_COMMIT
    else
        echo "Unknown"
    fi
}

# Функция для проверки обновлений для Stable
check_stable_updates() {
    info "Проверка обновлений для Stable..."

    # Получаем текущую версию
    CURRENT_VERSION=$(get_system_version)

    # Получаем последний релиз через GitHub API с обработкой ошибок
    API_RESPONSE=$(curl -s -H "Accept: application/vnd.github.v3+json" \
        -w "\nHTTP_CODE:%{http_code}" \
        https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest)

    # Извлекаем HTTP код
    HTTP_CODE=$(echo "$API_RESPONSE" | grep 'HTTP_CODE:' | cut -d':' -f2)
    JSON_RESPONSE=$(echo "$API_RESPONSE" | sed '/HTTP_CODE:/d')

    # Проверяем успешность запроса
    if [ "$HTTP_CODE" != "200" ]; then
        info "Ошибка: не удалось получить данные от GitHub API (код $HTTP_CODE)" >&2
        info "Ответ API: $JSON_RESPONSE" >&2
        return 1
    fi

    # Извлекаем версию релиза
    LATEST_RELEASE=$(echo "$JSON_RESPONSE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    # Проверяем успешность выполнения
    if [ -z "$LATEST_RELEASE" ]; then
        info "Ошибка: не удалось получить информацию о релизе" >&2
        return 1
    fi

    # Сравниваем версии
    if [ "$LATEST_RELEASE" != "$CURRENT_VERSION" ]; then
        if ! $NO_INFO; then
            info "Доступно обновление! Последняя версия: $LATEST_RELEASE"
        else
            echo $LATEST_RELEASE
        fi
    else
        info "Новые обновления не найдены."
    fi
}

# Функция для проверки обновлений для Developer
check_developer_updates() {
    info "Проверка обновлений для Developer..."

    CURRENT_COMMIT=$(get_system_version)
    LATEST_VERSION=$(check_github_commit developer $CURRENT_COMMIT)

    case $LATEST_VERSION in
        Unknown)
        info "Новые обновления не нашлись."
        ;;
        *)
        if ! $NO_INFO; then
            info "Доступно обновление! Последний коммит: $LATEST_VERSION"
        else
            echo $LATEST_VERSION
        fi
        ;;
    esac
}

# Функция для проверки обновлений для Experimental
check_experimental_updates() {
    info "Проверка обновлений для Experimental..."
    
    CURRENT_COMMIT=$(get_system_version)
    LATEST_VERSION=$(check_github_commit experimental $CURRENT_COMMIT)

    case $LATEST_VERSION in
        Unknown)
        info "Новые обновления не нашлись."
        ;;
        *)
        if ! $NO_INFO; then
            info "Доступно обновление! Последний коммит: $LATEST_VERSION"
        else
            echo $LATEST_VERSION
        fi
        ;;
    esac
}

# Основная логика скрипта

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      ;;
    -t|--type)
      if [[ -n $2 ]]; then
        TYPE="$2"
        shift
      else
        echo "Ошибка: Не указан тип системы после флага -t|--type" >&2
        exit 1
      fi
      ;;
    --no-info)
      NO_INFO=true
      ;;
    *)
      echo "Ошибка: Неизвестный аргумент '$1'" >&2
      show_help
      exit 1
      ;;
  esac
  shift
done

# Если тип не указан через флаг, пытаемся получить его из /etc/os-release
if [ -z "$TYPE" ]; then
    TYPE=$(grep '^BUILD_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
fi

# Проверка обновлений в зависимости от типа системы
case $TYPE in
    stable)
    check_stable_updates
    ;;
    developer)
    check_developer_updates
    ;;
    experimental)
    check_experimental_updates
    ;;
    *)
    echo "Неизвестный тип системы: $TYPE" >&2
    exit 1
    ;;
esac
