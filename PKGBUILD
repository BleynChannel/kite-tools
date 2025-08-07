# Maintainer: Bleyn <bleyn2017@gmail.com>
pkgname=kite-tools
pkgver=1.1.1
pkgrel=1
pkgdesc="Management and configuration tools for Kite system"
arch=('x86_64')
url="https://github.com/BleynChannel/kite-tools"
license=('GPL3')
depends=(
    'bash'
    'sudo'
    'git'
    'curl'
    'wget'
    'tar'
    'rsync'
)
makedepends=('git' 'rust')
provides=("${pkgname}")
conflicts=("${pkgname}")
source=("git+${url}.git")
sha256sums=('SKIP')

build() {
    cd "${srcdir}/${pkgname}"
    
    # If this is a Rust project, build it using cargo
    if [ -f "Cargo.toml" ]; then
        cargo build --release
    fi
}

package() {
    cd "${srcdir}/${pkgname}"
    
    # Install Bash scripts
    if [ -d "scripts" ]; then
        install -dm755 "${pkgdir}/usr/bin"
        mkdir -p "${pkgdir}/usr/src/${pkgname}"
        install -Dm755 scripts/* "${pkgdir}/usr/src/${pkgname}"
    fi
    
    # Install Rust binaries if they exist
    if [ -f "Cargo.toml" ]; then
        install -Dm755 "target/release/${pkgname}" "${pkgdir}/usr/bin/${pkgname}"
    fi
    
    # Install documentation
    install -Dm644 "README.md" "${pkgdir}/usr/share/doc/${pkgname}/README.md"
    
    # Install license
    install -Dm644 "LICENSE" "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
}