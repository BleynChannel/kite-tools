#!/bin/bash 

GITHUB_USER=BleynChannel
GITHUB_REPO=Kite-Dots

# Function to show help
show_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  -h, --help                          Show this help
  -v <version> | --version <version>  Skip check and specify system version
  --no-confirm                        Skip installation confirmation
  --no-info                           Disable info messages
  --no-reboot                         Skip system reboot

Examples:
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
        echo "Error: Version not specified after -v|--version flag" >&2
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
      echo "Error: Unknown argument '$1'" >&2
      show_help
      exit 1
      ;;
  esac
  shift
done

# Function to output information
info() {
  if [ "$NO_INFO" = false ]; then
    echo "[INFO] $1"
  fi
}

# Step 1: Check system ID
info "Checking system..."
ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
if [[ "$ID" != *"kite"* ]]; then
  echo "Error: Kite system update is not possible! Another system is installed." >&2
  exit 1
fi

SOURCE_DIR=$(dirname "$(realpath "$0")")
TYPE=$(grep '^BUILD_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

# Step 2: Check for updates
if [ -z "$VERSION" ]; then
  info "Checking for updates..."
  if [ -f "$SOURCE_DIR/check_update.sh" ]; then
    # Run check_update.sh and capture both output and exit status
    if ! NEW_VERSION=$("$SOURCE_DIR/check_update.sh" -t "$TYPE" --no-info 2>&1); then
      # If check_update.sh failed, show the error message and exit
      echo "Error: $NEW_VERSION" >&2
      exit 1
    fi
    
    # Check if we got a valid version or just an error message
    if [[ "$NEW_VERSION" == "Unknown" ]]; then
      info "No updates found"
      exit 0
    elif [ -n "$NEW_VERSION" ]; then
      info "New version found: $NEW_VERSION"
      VERSION=$NEW_VERSION
    else
      info "No updates found"
      exit 0
    fi
  else
    echo "Error: Update check script not found" >&2
    exit 1
  fi
else
  info "Update check skipped, using specified version: $VERSION"
fi

# Step 3: Confirm update
if [ "$NO_CONFIRM" = false ]; then
  read -p "Are you sure you want to update the Kite system? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Installation canceled by user"
    exit 0
  fi
fi

# Step 4: Update packages
if [ -f /var/lib/pacman/db.lck ]; then
  echo "Error: Pacman database is locked. Another pacman process may be running."
  echo "Try running: rm /var/lib/pacman/db.lck" >&2
  exit 1
fi

info "Updating packages..."
if ! pacman -Syu --noconfirm; then
    echo "Error: Failed to update packages" >&2
    exit 1
fi

# Step 5: Download and extract package
info "Downloading installation package..."
TEMP_DIR=$(mktemp -d)
chown -R "$SUDO_USER":"$SUDO_USER" "$TEMP_DIR"
case $TYPE in
  stable)
    if ! sudo -u $SUDO_USER git clone --depth 1 --branch $VERSION https://github.com/$GITHUB_USER/$GITHUB_REPO.git "$TEMP_DIR/kite"; then
        echo "Error: Failed to download installation package" >&2
        exit 1
    fi
    ;;
  developer)
    if ! sudo -u $SUDO_USER git clone --depth 1 --branch developer https://github.com/$GITHUB_USER/$GITHUB_REPO.git "$TEMP_DIR/kite"; then
        echo "Error: Failed to download installation package" >&2
        exit 1
    fi
    (cd "$TEMP_DIR/kite" && git checkout $VERSION)
    ;;
  experimental)
    if ! sudo -u $SUDO_USER git clone --depth 1 --branch experimental https://github.com/$GITHUB_USER/$GITHUB_REPO.git "$TEMP_DIR/kite"; then
        echo "Error: Failed to download installation package" >&2
        exit 1
    fi
    (cd "$TEMP_DIR/kite" && git checkout $VERSION)
    ;;
esac
PKG_DIR="$TEMP_DIR/kite"

# Initialize and download files via Git LFS
info "Initializing Git LFS..."
if ! (cd "$PKG_DIR" && git lfs install && git lfs pull); then
    echo "Error: Failed to initialize Git LFS" >&2
    exit 1
fi

# Step 6: Change version
if [ "$NO_INFO" = true ]; then
    info "Removing old version..."
    if ! bash "$SOURCE_DIR/uninstall.sh" full --no-confirm --no-reboot --no-info; then
        echo "Error: Uninstall script failed" >&2
        exit 1
    fi

    info "Running installation script..."
    if ! bash "$PKG_DIR/install.sh" --no-info; then
        echo "Error: Installation script failed" >&2
        exit 1
    fi
else
    info "Removing old version..."
    if ! bash "$SOURCE_DIR/uninstall.sh" full --no-confirm --no-reboot; then
        echo "Error: Uninstall script failed" >&2
        exit 1
    fi

    info "Running installation script..."
    if ! bash "$PKG_DIR/install.sh"; then
        echo "Error: Installation script failed" >&2
        exit 1
    fi
fi

# Step 7: Backup os-release
info "Creating os-release backup..."
if ! cp /etc/os-release /etc/os-release.backup; then
    echo "Error: Failed to create os-release backup" >&2
    exit 1
fi

# Step 8: Copy files
info "Copying system files..."
if ! cp -f "$PKG_DIR/os-release" /etc/; then
    echo "Error: Failed to copy os-release" >&2
    exit 1
fi
if ! cp -f "$PKG_DIR/uninstall.sh" /usr/src/kite-tools/; then
    echo "Error: Failed to copy uninstall.sh" >&2
    exit 1
fi

# Step 9: Change BUILD_ID and VERSION_ID in os-release
info "Applying new changes to system..."
# sed -i "s/BUILD_ID=.*$/BUILD_ID=$TYPE/" /etc/os-release
if ! sed -i "s/VERSION_ID=.*$/VERSION_ID=$VERSION/" /etc/os-release; then
    echo "Error: Failed to update os-release" >&2
    exit 1
fi

# Cleanup
info "Cleaning up temporary files..."
if ! rm -rf "$TEMP_DIR"; then
    echo "Error: Failed to clean up temporary files" >&2
    exit 1
fi

info "Kite system update completed successfully!"

# Reboot system
if [ "$NO_REBOOT" = false ]; then
  info "System reboot will start in 5 seconds..."
  sleep 5
  reboot
fi