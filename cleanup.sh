#!/usr/bin/env bash

set -euo pipefail

PACMAN_LOG="/var/log/pacman.log"
LOG_KEEP_LINES=1000
BACKUP_DIR="$HOME/.local/share/pkgbackup"
BACKUP_FILE="$BACKUP_DIR/pkglist.txt"

REAL_USER="${SUDO_USER:-$USER}"

freed=0
declare -A section_freed

TOTAL_STEPS=7
current_step=0

notify_progress() {
    local msg="$1"
    current_step=$(( current_step + 1 ))
    local pct=$(( current_step * 100 / TOTAL_STEPS ))
    su -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$REAL_USER")/bus \
        notify-send -a 'System Cleanup' -h 'int:value:$pct' 'Cleaning... $pct%' '$msg'" \
        "$REAL_USER" 2>/dev/null || true
}

notify_done() {
    local title="$1"
    local body="$2"
    su -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$REAL_USER")/bus \
        notify-send -a 'System Cleanup' '$title' '$body'" \
        "$REAL_USER" 2>/dev/null || true
}

track() {
    local name="$1"
    local before="$2"
    local after="$3"
    local diff=$(( before - after ))
    section_freed["$name"]=$diff
    freed=$(( freed + diff ))
}

mkdir -p "$BACKUP_DIR"

notify_progress "Saving package list backup..."
pacman -Qqe > "$BACKUP_FILE"

notify_progress "Clearing pacman + AUR cache..."
before=$(du -sb /var/cache/pacman/pkg/ 2>/dev/null | cut -f1 || echo 0)
paccache -rk0 --nocolor 2>/dev/null
paccache -ruk0 --nocolor 2>/dev/null
after=$(du -sb /var/cache/pacman/pkg/ 2>/dev/null | cut -f1 || echo 0)
track "pacman cache" "$before" "$after"

REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

if [[ -d "$REAL_HOME/.cache/yay" ]]; then
    before=$(du -sb "$REAL_HOME/.cache/yay" 2>/dev/null | cut -f1 || echo 0)
    rm -rf "$REAL_HOME/.cache/yay"
    track "yay cache" "$before" 0
fi

if [[ -d "$REAL_HOME/.cache/paru" ]]; then
    before=$(du -sb "$REAL_HOME/.cache/paru" 2>/dev/null | cut -f1 || echo 0)
    rm -rf "$REAL_HOME/.cache/paru"
    track "paru cache" "$before" 0
fi

notify_progress "Removing orphaned dependencies..."
orphans=$(pacman -Qdtq 2>/dev/null || true)
if [[ -n "$orphans" ]]; then
    echo "$orphans" | pacman -Rns --noconfirm - 2>/dev/null || true
fi

notify_progress "Trimming pacman log..."
if [[ -f "$PACMAN_LOG" ]]; then
    before=$(wc -c < "$PACMAN_LOG")
    tmp=$(mktemp)
    tail -n "$LOG_KEEP_LINES" "$PACMAN_LOG" > "$tmp"
    mv "$tmp" "$PACMAN_LOG"
    after=$(wc -c < "$PACMAN_LOG")
    track "pacman log" "$before" "$after"
fi

notify_progress "Vacuuming systemd journal..."
before=$(du -sb /var/log/journal/ 2>/dev/null | cut -f1 || echo 0)
journalctl --vacuum-size=50M 2>/dev/null || true
after=$(du -sb /var/log/journal/ 2>/dev/null | cut -f1 || echo 0)
track "journal" "$before" "$after"

notify_progress "Clearing user cache..."
if [[ -d "$REAL_HOME/.cache" ]]; then
    before=$(du -sb "$REAL_HOME/.cache" 2>/dev/null | cut -f1 || echo 0)

    safe_dirs=(
        thumbnail thumbnails mesa_shader_cache nvidia
        fontconfig icon-cache.kcache gstreamer-1.0
        gio gtk-4.0 gtk-3.0 pipewire nv
    )

    for dir in "${safe_dirs[@]}"; do
        target="$REAL_HOME/.cache/$dir"
        [[ -d "$target" ]] && rm -rf "$target"
    done

    find "$REAL_HOME/.cache" -maxdepth 2 -name "*.log" -mtime +30 -delete 2>/dev/null || true
    find "$REAL_HOME/.cache" -maxdepth 2 -name "*.tmp" -delete 2>/dev/null || true

    after=$(du -sb "$REAL_HOME/.cache" 2>/dev/null | cut -f1 || echo 0)
    track "user cache" "$before" "$after"
fi

notify_progress "Clearing pip cache..."
if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
    before=$(du -sb "$REAL_HOME/.cache/pip" 2>/dev/null | cut -f1 || echo 0)
    su -c "pip cache purge 2>/dev/null || pip3 cache purge 2>/dev/null || true" "$REAL_USER"
    after=$(du -sb "$REAL_HOME/.cache/pip" 2>/dev/null | cut -f1 || echo 0)
    track "pip cache" "$before" "$after"
fi

body=""
for key in "pacman cache" "yay cache" "paru cache" "journal" "user cache" "pip cache" "pacman log"; do
    val="${section_freed[$key]:-0}"
    if [[ $val -gt 1024 ]]; then
        body+="$(printf '%-14s' "$key")  $(numfmt --to=iec $val)\n"
    fi
done

total_hr=$(numfmt --to=iec $freed)

notify_done "Done — freed $total_hr" "$(echo -e "$body")"
