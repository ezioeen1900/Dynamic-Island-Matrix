#!/usr/bin/env bash
# ==============================================================================
# Glyph Island Edition — Public One-Command Installer (Hyprland + Quickshell)
# Usage:
#   ./deploy.sh               Full install (Arch/CachyOS packages + links + SDDM + Plymouth)
#   ./deploy.sh --with-refind Full install + rEFInd bootloader theme
#   ./deploy.sh --links-only  User-space symlinks & defaults only (any distro, no sudo)
# ==============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-full}"

say() { printf '\n\033[1;31m●\033[0m \033[1m%s\033[0m\n' "$*"; }

install_packages() {
    command -v pacman >/dev/null || return 0
    say "Installing required packages..."
    local pkgs=(
        hyprland quickshell xdg-desktop-portal-hyprland
        qt5-wayland qt6-wayland qt6-multimedia-ffmpeg qt6-svg qt6-5compat
        polkit-gnome networkmanager bluez bluez-utils blueman
        pipewire pipewire-pulse wireplumber
        brightnessctl playerctl wl-clipboard cliphist
        grim slurp swappy hyprpicker hypridle hyprsunset
        libqalculate libvips jq
        kitty fish starship fastfetch btop cava eza zoxide direnv ydotool trash-cli
        thunar pavucontrol papirus-icon-theme adw-gtk-theme
        noto-fonts-cjk noto-fonts-emoji
    )
    sudo pacman -S --needed --noconfirm "${pkgs[@]}" || true
}

install_links() {
    mkdir -p "$HOME/.local/bin"
    cp -a "$REPO_DIR/extras/bin/lyricsmpris" "$HOME/.local/bin/lyricsmpris"
    chmod +x "$HOME/.local/bin/lyricsmpris"

    bash "$REPO_DIR/install.sh" --links

    mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/rice"
    if [ ! -f "${XDG_STATE_HOME:-$HOME/.local/state}/rice/glyph.json" ]; then
        cp -a "$REPO_DIR/extras/defaults/glyph.json" "${XDG_STATE_HOME:-$HOME/.local/state}/rice/glyph.json"
    fi
}

install_system_themes() {
    say "Installing Glyph SDDM & Plymouth boot themes..."
    bash "$REPO_DIR/install.sh" --sddm || true
    sudo bash -c "
        set -euo pipefail
        if [ -d /usr/share/plymouth/themes ]; then
            rm -rf /usr/share/plymouth/themes/glyph
            cp -rT '$REPO_DIR/extras/plymouth/glyph' /usr/share/plymouth/themes/glyph
            chmod -R a+rX /usr/share/plymouth/themes/glyph
            plymouth-set-default-theme -R glyph
        fi
    "
}

install_refind_theme() {
    say "Installing Glyph rEFInd bootloader theme..."
    sudo bash -c "
        set -euo pipefail
        REFIND_DIR=/boot/efi/EFI/refind
        [ -d \"\$REFIND_DIR\" ] || REFIND_DIR=/boot/EFI/refind
        [ -f \"\$REFIND_DIR/refind.conf\" ] || { echo 'refind.conf not found, skipping'; exit 0; }
        cp -a \"\$REFIND_DIR/refind.conf\" \"\$REFIND_DIR/refind.conf.bak-\$(date +%F_%H-%M-%S)\"
        mkdir -p \"\$REFIND_DIR/themes\"
        rm -rf \"\$REFIND_DIR/themes/glyph\"
        cp -rT '$REPO_DIR/extras/refind/glyph' \"\$REFIND_DIR/themes/glyph\"
        grep -q 'themes/glyph/theme.conf' \"\$REFIND_DIR/refind.conf\" || printf '\ninclude themes/glyph/theme.conf\n' >> \"\$REFIND_DIR/refind.conf\"
    "
}

case "$MODE" in
    --links-only)
        install_links
        ;;
    full|"")
        install_packages
        install_links
        install_system_themes
        ;;
    --with-refind)
        install_packages
        install_links
        install_system_themes
        install_refind_theme
        ;;
    *)
        sed -n '4,7s/^# //p' "$0"
        exit 1
        ;;
esac

say "Done! Run: ~/.local/bin/rice restart"
