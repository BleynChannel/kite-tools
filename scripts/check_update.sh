#!/bin/bash

# Флаг для отключения вывода информации
GITHUB_USER=BleynChannel
GITHUB_REPO=Kite-Dots
NO_INFO=false

# Функция для получения типа системы из /etc/os-release
get_system_type() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $BUILD_ID in
            release) echo "Release" ;;
            developer) echo "Developer" ;;
            experimental) echo "Experimental" ;;
            *) echo "Unknown" ;;
        esac
    else
        echo "Unknown"
    fi
}

get_system_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $VERSION_ID
    else
        echo "Unknown"
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

# Функция для проверки обновлений для Release
check_release_updates() {
    if ! $NO_INFO; then
        echo "Проверка обновлений для Release..."
    fi

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
        if ! $NO_INFO; then
            echo "Ошибка: не удалось получить данные от GitHub API (код $HTTP_CODE)" >&2
            echo "Ответ API: $JSON_RESPONSE" >&2
        fi
        return 1
    fi

    # Извлекаем версию релиза
    LATEST_RELEASE=$(echo "$JSON_RESPONSE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    # Проверяем успешность выполнения
    if [ -z "$LATEST_RELEASE" ]; then
        if ! $NO_INFO; then
            echo "Ошибка: не удалось получить информацию о релизе" >&2
        fi
        return 1
    fi

    # Сравниваем версии
    if [ "$LATEST_RELEASE" != "$CURRENT_VERSION" ]; then
        if ! $NO_INFO; then
            echo "Доступно обновление! Последняя версия: $LATEST_RELEASE"
        else
            echo $LATEST_RELEASE
        fi
    else
        if ! $NO_INFO; then
            echo "Новые обновления не найдены."
        fi
    fi
}

# Функция для проверки обновлений для Developer
check_dev_updates() {
    if ! $NO_INFO; then
        echo "Проверка обновлений для Developer..."
    fi

    CURRENT_COMMIT=$(get_system_version)
    LATEST_VERSION=$(check_github_commit developer $CURRENT_COMMIT)

    case $LATEST_VERSION in
        Unknown)
        if ! $NO_INFO; then
            echo "Новые обновления не нашлись."
        fi
        ;;
        *)
        if ! $NO_INFO; then
            echo "Доступно обновление! Последний коммит: $LATEST_VERSION"
        else
            echo $LATEST_VERSION
        fi
        ;;
    esac
}

# Функция для проверки обновлений для Experimental
check_experimental_updates() {
    if ! $NO_INFO; then
        echo "Проверка обновлений для Experimental..."
    fi
    
    CURRENT_COMMIT=$(get_system_version)
    LATEST_VERSION=$(check_github_commit experimental $CURRENT_COMMIT)

    case $LATEST_VERSION in
        Unknown)
        if ! $NO_INFO; then
            echo "Новые обновления не нашлись."
        fi
        ;;
        *)
        if ! $NO_INFO; then
            echo "Доступно обновление! Последний коммит: $LATEST_VERSION"
        else
            echo $LATEST_VERSION
        fi
        ;;
    esac
}

# Основная логика скрипта
TYPE=""

# Парсинг аргументов командной строки
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -t|--type)
        TYPE="$2"
        shift
        shift
        ;;
        --no-info)
        NO_INFO=true
        shift
        ;;
        *)
        shift
        ;;
    esac
done

# Если тип не указан через флаг, пытаемся получить его из /etc/os-release
if [ -z "$TYPE" ]; then
    TYPE=$(get_system_type)
fi

# Проверка обновлений в зависимости от типа системы
case $TYPE in
    Release)
    check_release_updates
    ;;
    Developer)
    check_dev_updates
    ;;
    Experimental)
    check_experimental_updates
    ;;
    *)
    echo "Unknown system type: $TYPE"
    exit 1
    ;;
esac

exit 0