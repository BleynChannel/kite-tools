#!/bin/bash

# Function to display help
show_help() {
  cat <<EOF
Usage: $0 <category> [options]

Categories for removal:
  config - Remove configuration files
  apps - Remove applications
  full - Remove the entire system

Options:
  -h, --help     Show this help
  --no-confirm   Skip removal confirmation
  --no-info      Disable information messages
  --no-reboot    Skip system reboot

Examples:
  $0 config
  $0 full --no-confirm
EOF
  exit 0
}

# Check arguments
if [ $# -eq 0 ]; then
  show_help
  exit 1
fi

HOME_PATH=$(getent passwd "$SUDO_USER" | cut -d: -f6)

# Process arguments
CATEGORY=""
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
    config|apps|full)
      CATEGORY=$arg
      ;;
    *)
      echo "Error: Unknown argument '$arg'" >&2
      show_help
      exit 1
      ;;
  esac
done

# Check category
if [ -z "$CATEGORY" ]; then
  echo "Error: System type must be specified" >&2
  show_help
  exit 1
fi

# Function to display information
info() {
  if [ "$NO_INFO" = false ]; then
    echo "[INFO] $1"
  fi
}

# Step 1: Check system ID
info "Checking system..."
ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
if [[ "$ID" != *"kite"* ]]; then
  echo "Error: Kite system removal is not possible! Another system is installed." >&2
  exit 1
fi

# Step 2: Confirm removal
if [ "$NO_CONFIRM" = false ]; then
  read -p "Are you sure you want to remove the Kite system? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Removal canceled by user"
    exit 0
  fi
fi

# Removal functions
remove_config() {
  info "Removing configuration files..."
  
  for path in "$HOME_PATH/.config/sway" \
              "$HOME_PATH/.config/kitty" \
              "$HOME_PATH/.config/waybar" \
              "$HOME_PATH/.config/ranger" \
              "$HOME_PATH/.config/fastfetch" \
              "$HOME_PATH/.config/fish" \
              /etc/mosquitto.conf; do
    if ! rm -r "$path"; then
      echo "Error: Could not remove '$path'" >&2
      exit 1
    fi
  done

  info "Removing configuration files completed successfully!"
}

remove_apps() {
  info "Removing applications..."
  
  if ! pacman -R --noconfirm pacman-contrib arc-solid-gtk-theme papirus-icon-theme \
                     woff2-font-awesome otf-font-awesome \
                     noto-fonts-emoji noto-fonts noto-fonts-cjk noto-fonts-extra terminus-font \
                     lightdm lightdm-gtk-greeter sway swaybg waybar mosquitto kitty; then
    echo "Error: Failed to remove applications" >&2
    exit 1
  fi

  # Developer tools
  if ! pacman -R --noconfirm fish starship eza neovim fastfetch btop \
                     ranger python-pillow; then
    echo "Error: Failed to remove applications" >&2
    exit 1
  fi

  # Return to user's default shell
  if ! chsh -s /bin/bash; then
    echo "Error: Failed to change default shell" >&2
    exit 1
  fi
  
  info "Removing applications completed successfully!"
}

remove_full() {
  info "Removing the entire system..."
  remove_config
  remove_apps

  # Remove main program
  if ! pacman -R --noconfirm kite-appimage; then
    echo "Error: Failed to remove main program" >&2
    exit 1
  fi

  # Restore os-release
  info "Restoring os-release..."
  if ! cp /etc/os-release.backup /etc/os-release; then
    echo "Error: Failed to restore os-release" >&2
    exit 1
  fi

  info "Removing the entire system completed successfully!"

  # Reboot system
  if [ "$NO_REBOOT" = false ]; then
    info "System reboot will start in 5 seconds..."
    sleep 5
    reboot
  fi
}

# Step 3: Perform removal
case $CATEGORY in
  config)
    remove_config
    ;;
  apps)
    remove_apps
    ;;
  full)
    remove_full
    ;;
  *)
    echo "Error: Unknown category '$CATEGORY'" >&2
    show_help
    exit 1
    ;;
esac