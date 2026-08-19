#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# MoviVIP Network — Multi-Distro Package Manager Functions
# Soporta: Ubuntu, Debian, openSUSE Leap, Oracle Linux, Arch Linux
# ═══════════════════════════════════════════════════════════════

# Detectar gestor de paquetes
if [[ -z "$PKG" ]]; then
    source /etc/os-release 2>/dev/null
    case "$ID" in
        ubuntu|debian)       PKG="apt" ;;
        opensuse*|suse|sles) PKG="zypper" ;;
        ol|rhel|centos|rocky|almalinux) PKG="dnf" ;;
        arch|manjaro)        PKG="pacman" ;;
        *)                   PKG="apt" ;;  # fallback
    esac
fi

pkg_update() {
    case "$PKG" in
        apt)    apt-get update -y ;;
        zypper) zypper --non-interactive refresh ;;
        dnf)    dnf makecache -y ;;
        pacman) pacman -Sy --noconfirm ;;
    esac
}

pkg_install() {
    case "$PKG" in
        apt)    apt-get install -y "$@" ;;
        zypper) zypper --non-interactive install -y "$@" ;;
        dnf)    dnf install -y "$@" ;;
        pacman) pacman -S --noconfirm --needed "$@" ;;
    esac
}

pkg_remove() {
    case "$PKG" in
        apt)    apt-get purge -y "$@" ;;
        zypper) zypper --non-interactive remove -y "$@" ;;
        dnf)    dnf remove -y "$@" ;;
        pacman) pacman -Rns --noconfirm "$@" ;;
    esac
}

pkg_clean() {
    case "$PKG" in
        apt)    apt-get autoremove -y; apt-get clean ;;
        zypper) zypper clean ;;
        dnf)    dnf autoremove -y; dnf clean all ;;
        pacman) pacman -Scc --noconfirm ;;
    esac
}
