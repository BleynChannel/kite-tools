#!/bin/bash

GITHUB_USER=BleynChannel
GITHUB_REPO=Kite-Dots

# Function to show help
show_help() {
  cat <<EOF
Usage: $0 <system_type> [options]

System types:
  stable       - Install stable version
  developer    - Install developer version
  experimental - Install experimental version

Options:
  -h, --help     Show this help
  --no-confirm   Skip installation confirmation
  --no-info      Disable info messages
  --no-reboot    Skip system reboot

Examples:
  $0 stable
  $0 developer --no-confirm
EOF
  exit 0
}

# Check arguments
if [ $# -eq 0 ]; then
  show_help
  exit 1
fi

# Process arguments
TYPE=""
NO_CONFIRM=false
NO_INFO=false
NO_REBOOT=false

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
    --no-reboot)
      NO_REBOOT=true
      ;;
    stable|developer|experimental)
      TYPE=$arg
      ;;
    *)
      echo "Error: Unknown argument '$arg'" >&2
      show_help
      exit 1
      ;;
  esac
done

# Check system type
if [ -z "$TYPE" ]; then
  echo "Error: System type must be specified" >&2
  show_help
  exit 1
fi

# Function to output information
info() {
  if [ "$NO_INFO" = false ]; then
    echo "[INFO] $1"
  fi
}

# Step 1: Check system ID
info "Checking system..."
ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
if [[ "$ID" == *"kite"* ]]; then
  echo "Error: System is already installed!" >&2
  exit 1
fi

# Step 2: Confirm installation
if [ "$NO_CONFIRM" = false ]; then
  read -p "Are you sure you want to install the Kite system ($TYPE)? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Installation canceled by user"
    exit 0
  fi
fi

TEMP_DIR=$(mktemp -d)
chown -R "$SUDO_USER":"$SUDO_USER" "$TEMP_DIR"

# Step 3: Update packages
if [ -f /var/lib/pacman/db.lck ]; then
  echo -e "Error: Pacman database is locked. Another pacman process may be running.\nTry running: sudo rm /var/lib/pacman/db.lck" >&2
  exit 1
fi

info "Updating packages..."
if ! pacman -Syu --noconfirm git git-lfs; then
    echo "Error: Failed to update packages" >&2
    exit 1
fi

# Step 4: Download and extract package
info "Downloading installation package..."
case $TYPE in
  stable)
    API_URL="https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"
    RESPONSE=$(curl -s $API_URL)
    VERSION=$(echo "$RESPONSE" | grep -oP '"tag_name": "\K[^"]+')
    if [ -z "$VERSION" ]; then
      echo "Error: Failed to get release version" >&2
      exit 1
    fi
    if ! sudo -u $SUDO_USER git clone --depth 1 --branch $VERSION https://github.com/$GITHUB_USER/$GITHUB_REPO.git "$TEMP_DIR/kite"; then
      echo "Error: Failed to download installation package" >&2
      exit 1
    fi
    ;;
  developer)
    VERSION=$(git ls-remote https://github.com/$GITHUB_USER/$GITHUB_REPO.git refs/heads/developer | cut -f1)
    if [ -z "$VERSION" ]; then
      echo "Error: Failed to get commit hash for developer branch" >&2
      exit 1
    fi
    if ! sudo -u $SUDO_USER git clone --depth 1 --branch developer https://github.com/$GITHUB_USER/$GITHUB_REPO.git "$TEMP_DIR/kite"; then
      echo "Error: Failed to download installation package" >&2
      exit 1
    fi
    ;;
  experimental)
    VERSION=$(git ls-remote https://github.com/$GITHUB_USER/$GITHUB_REPO.git refs/heads/experimental | cut -f1)
    if [ -z "$VERSION" ]; then
      echo "Error: Failed to get commit hash for experimental branch" >&2
      exit 1
    fi
    if ! sudo -u $SUDO_USER git clone --depth 1 --branch experimental https://github.com/$GITHUB_USER/$GITHUB_REPO.git "$TEMP_DIR/kite"; then
      echo "Error: Failed to download installation package" >&2
      exit 1
    fi
    ;;
esac
PKG_DIR="$TEMP_DIR/kite"

# Initialize and download files via Git LFS
info "Initializing Git LFS..."
if ! (cd "$PKG_DIR" && git lfs install && git lfs pull); then
    echo "Error: Failed to initialize Git LFS" >&2
    exit 1
fi

# Step 5: Run installation script
if [ "$NO_INFO" = true ]; then
  if ! bash "$PKG_DIR/install.sh" --no-info; then
    echo "Error: Installation script failed" >&2
    exit 1
  fi
else
  if ! bash "$PKG_DIR/install.sh"; then
    echo "Error: Installation script failed" >&2
    exit 1
  fi
fi

# Step 6: Backup os-release
info "Creating os-release backup..."
if ! cp /etc/os-release /etc/os-release.backup; then
    echo "Error: Failed to create os-release backup" >&2
    exit 1
fi

# Step 7: Copy files
info "Copying system files..."
if ! cp "$PKG_DIR/os-release" /etc/; then
    echo "Error: Failed to copy os-release" >&2
    exit 1
fi
if ! cp "$PKG_DIR/uninstall.sh" /usr/src/kite-tools/; then
    echo "Error: Failed to copy uninstall.sh" >&2
    exit 1
fi

# Step 8: Change BUILD_ID and VERSION_ID in os-release
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

info "Kite system installation completed successfully!"

# Reboot system
if [ "$NO_REBOOT" = false ]; then
  info "System reboot will start in 5 seconds..."
  sleep 5
  reboot
fi