#!/bin/bash

# Flag to disable info output
GITHUB_USER=BleynChannel
GITHUB_REPO=Kite-Dots

# Function to show help
show_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  -h, --help     Show this help
  -t, --type     System type (stable, developer, experimental)
  --no-info      Disable info messages

Examples:
  $0
  $0 -t stable --no-info
EOF
  exit 0
}

# Обработка аргументов
TYPE=""
NO_INFO=false

# Function to output information
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

    # Get the latest commit from the repository considering the branch
    LATEST_COMMIT=$(git ls-remote https://github.com/$GITHUB_USER/$GITHUB_REPO.git refs/heads/$BRANCH 2>/dev/null | awk '{print $1}')

    # Check command execution success
    if [ $? -ne 0 ]; then
        echo "Error: Failed to get data from repository" >&2
        echo "Unknown"
        return 1
    fi

    # Check that commit was received
    if [ -z "$LATEST_COMMIT" ]; then
        echo "Error: Branch $BRANCH not found" >&2
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

# Function to check updates for Stable
check_stable_updates() {
    info "Checking updates for Stable..."

    # Get current version
    CURRENT_VERSION=$(get_system_version)

    # Get latest release via GitHub API with error handling
    API_RESPONSE=$(curl -s -H "Accept: application/vnd.github.v3+json" \
        -w "\nHTTP_CODE:%{http_code}" \
        https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest)

    # Extract HTTP code
    HTTP_CODE=$(echo "$API_RESPONSE" | grep 'HTTP_CODE:' | cut -d':' -f2)
    JSON_RESPONSE=$(echo "$API_RESPONSE" | sed '/HTTP_CODE:/d')

    # Check request success
    if [ "$HTTP_CODE" != "200" ]; then
        info "Error: Failed to get data from GitHub API (code $HTTP_CODE)" >&2
        info "API response: $JSON_RESPONSE" >&2
        return 1
    fi

    # Extract release version
    LATEST_RELEASE=$(echo "$JSON_RESPONSE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    # Check execution success
    if [ -z "$LATEST_RELEASE" ]; then
        info "Error: Failed to get release information" >&2
        return 1
    fi

    # Compare versions
    if [ "$LATEST_RELEASE" != "$CURRENT_VERSION" ]; then
        if ! $NO_INFO; then
            info "Update available! Latest version: $LATEST_RELEASE"
        else
            echo $LATEST_RELEASE
        fi
    else
        info "No new updates found."
    fi
}

# Function to check updates for Developer
check_developer_updates() {
    info "Checking updates for Developer..."

    CURRENT_COMMIT=$(get_system_version)
    LATEST_VERSION=$(check_github_commit developer $CURRENT_COMMIT)

    case $LATEST_VERSION in
        Unknown)
        info "No new updates found."
        ;;
        *)
        if ! $NO_INFO; then
            info "Update available! Latest commit: $LATEST_VERSION"
        else
            echo $LATEST_VERSION
        fi
        ;;
    esac
}

# Function to check updates for Experimental
check_experimental_updates() {
    info "Checking updates for Experimental..."
    
    CURRENT_COMMIT=$(get_system_version)
    LATEST_VERSION=$(check_github_commit experimental $CURRENT_COMMIT)

    case $LATEST_VERSION in
        Unknown)
        info "No new updates found."
        ;;
        *)
        if ! $NO_INFO; then
            info "Update available! Latest commit: $LATEST_VERSION"
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
        echo "Error: System type not specified after -t|--type flag" >&2
        exit 1
      fi
      ;;
    --no-info)
      NO_INFO=true
      ;;
    *)
      echo "Error: Unknown argument '$1'" >&2
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

# Check updates depending on system type
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
    echo "Unknown system type: $TYPE" >&2
    exit 1
    ;;
esac
