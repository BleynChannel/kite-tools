# Kite System Management Tools

## Overview
`kite-tools` is a Rust-based command-line and TUI application for managing the Kite system. It provides an interactive interface for system installation, restoration, updates, and package management.

## Features
- Interactive TUI mode
- Command-line interface
- System installation
- System restoration
- System updates
- System uninstallation
- Custom package installation

## Prerequisites
- Rust (latest stable version)
- Cargo
- Bash
- Sudo access

## Installation
### 1. Automatic Installation via AUR (Recommended)
```bash
[yay|paru|etc] -Syu kite-tools
```

### 2. Automatic Installation via GitHub repository
```bash
git clone https://github.com/BleynChannel/kite-tools && cd kite-tools
makepkg -si
```

### 3. Manual Installation
1. Install depends
```bash
sudo pacman -S git base-devel cargo
```

2. Download repository
```bash
git clone https://github.com/BleynChannel/kite-tools && cd kite-tools
```

3. Copy scripts and build Rust program
```bash
sudo mkdir -p /usr/src/kite-tools && sudo cp scripts/* /usr/src/kite-tools
cargo build --release && sudo cp target/release/kite-tools /usr/local/bin/
```

## Usage

### Interactive TUI Mode
Simply run the tool without arguments:
```bash
kite-tools
```

### Command-line Options (WIP)
```bash
# Install the system
kite-tools install

# Restore the system
kite-tools restore

# Update the system
kite-tools update

# Uninstall the system
kite-tools uninstall

# Install custom packages
kite-tools install-package
```

## Keyboard Shortcuts (TUI Mode) (WIP)
- `i`: Install system
- `r`: Restore system
- `u`: Update system
- `c`: Uninstall system
- `p`: Install packages
- `q`: Quit application

## Requirements
- Kite system scripts must be located in `/usr/local/bin/kite-tools/`

## License
[Your License Here]

## Contributing
Contributions are welcome! Please submit pull requests or open issues on our repository.