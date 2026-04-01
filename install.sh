#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

# aur helper
for helper in yay paru pikaur aurman; do
    command -v "$helper" &>/dev/null && AUR="$helper" && break
done
[[ -z "${AUR:-}" ]] && echo "no aur helper found" && exit 1

backup_if_exists() {
    local target="$1"
    [[ -e "$target" || -L "$target" ]] || return 0
    local dst="$BACKUP_DIR/${target#$HOME/}"
    mkdir -p "$(dirname "$dst")"
    cp -r "$target" "$dst"
}

deploy() {
    local src="$1" dst="$2"
    backup_if_exists "$dst"
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
}

# packages
sudo pacman -S --needed --noconfirm \
    kitty ttf-jetbrains-mono-nerd \
    hyprlock hypridle swww hyprpicker slurp grim wl-clipboard \
    rofi-wayland swaync \
    pamixer playerctl easyeffects pipewire pipewire-pulse ladspa cava \
    brightnessctl acpi iw bluez bluez-utils libnotify imagemagick \
    networkmanager socat bc fd ripgrep jq tree fortune-mod gtk3 cliphist \
    python python-requests satty

"$AUR" -S --needed --noconfirm \
    matugen-bin swayosd-git hyprshot quickshell-git arc-midnight-cursors

# fonts
mkdir -p "$HOME/.local/share/fonts"
cp -r "$REPO_DIR/config/fonts/JetBrainsMono/." "$HOME/.local/share/fonts/"
cp "$REPO_DIR/config/fonts/iosevka-nerd-font.ttf" "$HOME/.local/share/fonts/"
fc-cache -f

# backup existing
for c in kitty rofi swaync swayosd cava matugen; do
    backup_if_exists "$HOME/.config/$c"
done

# program configs
deploy "$REPO_DIR/config/programs/kitty/kitty.conf"   "$HOME/.config/kitty/kitty.conf"
deploy "$REPO_DIR/config/programs/rofi/config.rasi"   "$HOME/.config/rofi/config.rasi"
deploy "$REPO_DIR/config/programs/rofi/theme.rasi"    "$HOME/.config/rofi/theme.rasi"
deploy "$REPO_DIR/config/programs/swaync/config.json" "$HOME/.config/swaync/config.json"
deploy "$REPO_DIR/config/programs/swaync/style.css"   "$HOME/.config/swaync/style.css"
deploy "$REPO_DIR/config/programs/swayosd/style.css"  "$HOME/.config/swayosd/style.css"

# cava
mkdir -p "$HOME/.config/cava"
cp "$REPO_DIR/config/programs/cava/config" "$HOME/.config/cava/config_base"
cat > "$HOME/.config/cava/colors" << 'EOF'
[color]
background = '#1e1e2e'
foreground = '#cba6f7'
gradient = 1
gradient_count = 6
gradient_color_1 = '#cba6f7'
gradient_color_2 = '#89b4fa'
gradient_color_3 = '#94e2d5'
gradient_color_4 = '#f38ba8'
gradient_color_5 = '#b4befe'
gradient_color_6 = '#89dceb'
EOF
cat "$HOME/.config/cava/config_base" "$HOME/.config/cava/colors" > "$HOME/.config/cava/config"

# matugen templates
mkdir -p "$HOME/.config/matugen/templates/websites"
for f in kitty-colors.conf.template cava-colors.ini.template nvim-colors.lua.template discord.css.template firefox.css; do
    deploy "$REPO_DIR/config/programs/matugen/templates/$f" "$HOME/.config/matugen/templates/$f"
done
deploy "$REPO_DIR/config/programs/matugen/templates/websites/github.css.template"  "$HOME/.config/matugen/templates/websites/github.css.template"
deploy "$REPO_DIR/config/programs/matugen/templates/websites/youtube.css.template" "$HOME/.config/matugen/templates/websites/youtube.css.template"

cat > "$HOME/.config/matugen/config.toml" << 'EOF'
[config]
reload_apps = false

[templates.quickshell]
input_path  = "~/.config/hypr/scripts/quickshell/colors.json.template"
output_path = "/tmp/qs_colors.json"

[templates.kitty]
input_path  = "~/.config/matugen/templates/kitty-colors.conf.template"
output_path = "/tmp/kitty-matugen-colors.conf"

[templates.discord]
input_path  = "~/.config/matugen/templates/discord.css.template"
output_path = "~/.config/vesktop/themes/matugen.theme.css"

# firefox — uncomment and set your profile id
# [templates.firefox]
# input_path  = "~/.config/matugen/templates/firefox.css"
# output_path = "~/.mozilla/firefox/YOUR_PROFILE/chrome/matugen.css"

[templates.neovim]
input_path  = "~/.config/matugen/templates/nvim-colors.lua.template"
output_path = "~/.config/nvim/matugen_colors.lua"

[templates.cava]
input_path  = "~/.config/matugen/templates/cava-colors.ini.template"
output_path = "~/.config/cava/colors"

[templates.hyprlock]
input_path  = "~/.config/hypr/hyprlock/colors.conf.template"
output_path = "~/.config/hypr/hyprlock/colors.conf"
EOF

# hypr scripts
mkdir -p "$HOME/.config/hypr/scripts"
cp -r "$REPO_DIR/config/sessions/hyprland-cachy/scripts/." "$HOME/.config/hypr/scripts/"
sed -i 's/\.kitty-wrapped/kitty/g' "$HOME/.config/hypr/scripts/quickshell/wallpaper/matugen_reload.sh"
find "$HOME/.config/hypr/scripts" -name "*.sh" -exec chmod +x {} \;
find "$HOME/.config/hypr/scripts" -name "*.py" -exec chmod +x {} \;

# hyprlock
mkdir -p "$HOME/.config/hypr/hyprlock/scripts"
deploy "$REPO_DIR/config/sessions/hyprland-cachy/hyprlock.conf"                    "$HOME/.config/hypr/hyprlock.conf"
deploy "$REPO_DIR/config/sessions/hyprland-cachy/hyprlock/colors.conf.template"    "$HOME/.config/hypr/hyprlock/colors.conf.template"
deploy "$REPO_DIR/config/sessions/hyprland-cachy/hyprlock/scripts/battery.sh"      "$HOME/.config/hypr/hyprlock/scripts/battery.sh"
deploy "$REPO_DIR/config/sessions/hyprland-cachy/hyprlock/scripts/layout.sh"       "$HOME/.config/hypr/hyprlock/scripts/layout.sh"
chmod +x "$HOME/.config/hypr/hyprlock/scripts/"*.sh

# fallback colors so things start before first matugen run
cat > "$HOME/.config/hypr/hyprlock/colors.conf" << 'EOF'
$base      = rgb(1e1e2e)
$mantle    = rgb(181825)
$crust     = rgb(11111b)
$text      = rgb(cdd6f4)
$subtext0  = rgb(a6adc8)
$surface0  = rgb(313244)
$mauve     = rgb(cba6f7)
$green     = rgb(a6e3a1)
$red       = rgb(f38ba8)
$peach     = rgb(fab387)
$base_alpha85   = rgba(1e1e2eD9)
$mantle_alpha60 = rgba(18182599)
$mauve_alpha30  = rgba(cba6f74D)
EOF

cat > "/tmp/kitty-matugen-colors.conf" << 'EOF'
foreground              #cdd6f4
background              #1e1e2e
selection_foreground    #1e1e2e
selection_background    #cba6f7
cursor                  #cba6f7
cursor_text_color       #1e1e2e
url_color               #a6e3a1
active_border_color     #cba6f7
inactive_border_color   #313244
bell_border_color       #f38ba8
active_tab_foreground   #1e1e2e
active_tab_background   #cba6f7
inactive_tab_foreground #a6adc8
inactive_tab_background #313244
tab_bar_background      #1e1e2e
color0  #1e1e2e
color8  #313244
color1  #f38ba8
color9  #f38ba8
color2  #cba6f7
color10 #cba6f7
color3  #a6e3a1
color11 #a6e3a1
color4  #89b4fa
color12 #89b4fa
color5  #b4befe
color13 #b4befe
color6  #94e2d5
color14 #94e2d5
color7  #cdd6f4
color15 #cdd6f4
EOF

cat > "/tmp/qs_colors.json" << 'EOF'
{
  "base":     "#11111b", "mantle":   "#181825", "crust":    "#1e1e2e",
  "text":     "#cdd6f4", "subtext0": "#a6adc8", "subtext1": "#7f849c",
  "surface0": "#313244", "surface1": "#45475a", "surface2": "#585b70",
  "overlay0": "#45475a", "overlay1": "#45475a", "overlay2": "#45475a",
  "blue":     "#89b4fa", "sapphire": "#74c7ec", "peach":    "#fab387",
  "green":    "#a6e3a1", "red":      "#f38ba8", "mauve":    "#cba6f7",
  "pink":     "#f5c2e7", "yellow":   "#f9e2af", "maroon":   "#eba0ac",
  "teal":     "#94e2d5"
}
EOF

# hypridle
cp "$REPO_DIR/config/sessions/hyprland-cachy/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"

# hyprland visual config (source this from hyprland.conf)
cp "$REPO_DIR/config/sessions/hyprland-cachy/general.conf"      "$HOME/.config/hypr/ilyamiro-look.conf"
cat "$REPO_DIR/config/sessions/hyprland-cachy/animations.conf" >> "$HOME/.config/hypr/ilyamiro-look.conf"
cat "$REPO_DIR/config/sessions/hyprland-cachy/input.conf"      >> "$HOME/.config/hypr/ilyamiro-look.conf"
cat "$REPO_DIR/config/sessions/hyprland-cachy/window-rules.conf" >> "$HOME/.config/hypr/ilyamiro-look.conf"
cat "$REPO_DIR/config/sessions/hyprland-cachy/autostart.conf"  >> "$HOME/.config/hypr/ilyamiro-look.conf"

# services
systemctl --user enable --now bluetooth.service   2>/dev/null || true
systemctl --user enable --now swayosd-server.service 2>/dev/null || true

echo "done. backups at $BACKUP_DIR"
echo ""
echo "add to hyprland.conf:  source = ~/.config/hypr/ilyamiro-look.conf"
echo "firefox profile:       uncomment firefox section in ~/.config/matugen/config.toml"
echo "first colors:          matugen image /path/to/wall.jpg"
