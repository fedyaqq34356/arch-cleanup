# arch-cleanup

A lightweight Bash script that cleans up disk space on Linux systems — package cache, orphaned dependencies, systemd journal, user cache, pip cache — and sends desktop notifications with a progress bar and a final summary of how much space was freed.

---

## What it does

- Saves a backup of all explicitly installed packages before doing anything
- Clears the pacman package cache completely (keeps 0 old versions)
- Clears AUR helper caches (yay, paru) if present
- Removes orphaned dependencies
- Trims the pacman log to the last 1000 lines
- Vacuums the systemd journal down to 50 MB
- Clears safe user cache directories (thumbnails, mesa shaders, fontconfig, etc.)
- Clears the pip package cache
- Sends a desktop notification at each step showing percent complete
- Sends a final notification listing exactly how much each section freed

---

## Requirements

- `pacman-contrib` — for `paccache`
- `libnotify` — for `notify-send`
- `systemd` — for `journalctl`
- `pip` or `pip3` — optional, for Python cache cleaning

---

## Installation

### Arch Linux

```bash
sudo pacman -S pacman-contrib libnotify

git clone https://github.com/yourusername/arch-cleanup.git
cd arch-cleanup

mkdir -p ~/.config/hypr/hyprland/scripts
cp cleanup.sh ~/.config/hypr/hyprland/scripts/cleanup.sh
chmod +x ~/.config/hypr/hyprland/scripts/cleanup.sh
```

Give the script passwordless sudo:

```bash
echo 'YOUR_USERNAME ALL=(ALL) NOPASSWD: /bin/bash /home/YOUR_USERNAME/.config/hypr/hyprland/scripts/cleanup.sh' | sudo tee /etc/sudoers.d/cleanup
```

---

### Fedora

```bash
sudo dnf install libnotify

git clone https://github.com/yourusername/arch-cleanup.git
cd arch-cleanup

mkdir -p ~/.local/bin
cp cleanup.sh ~/.local/bin/cleanup.sh
chmod +x ~/.local/bin/cleanup.sh
```

> **Note:** Fedora uses `dnf` instead of `pacman`. The pacman-specific sections (package cache, orphan removal, pacman log) will be skipped automatically. Journal and user cache cleaning work as-is.

Give the script passwordless sudo:

```bash
echo 'YOUR_USERNAME ALL=(ALL) NOPASSWD: /bin/bash /home/YOUR_USERNAME/.local/bin/cleanup.sh' | sudo tee /etc/sudoers.d/cleanup
```

---

### Debian / Ubuntu

```bash
sudo apt install libnotify-bin

git clone https://github.com/yourusername/arch-cleanup.git
cd arch-cleanup

mkdir -p ~/.local/bin
cp cleanup.sh ~/.local/bin/cleanup.sh
chmod +x ~/.local/bin/cleanup.sh
```

> **Note:** On Debian/Ubuntu the pacman sections are skipped. Journal and cache cleaning work normally.

Give the script passwordless sudo:

```bash
echo 'YOUR_USERNAME ALL=(ALL) NOPASSWD: /bin/bash /home/YOUR_USERNAME/.local/bin/cleanup.sh' | sudo tee /etc/sudoers.d/cleanup
```

---

### openSUSE

```bash
sudo zypper install libnotify-tools

git clone https://github.com/yourusername/arch-cleanup.git
cd arch-cleanup
cp cleanup.sh ~/.local/bin/cleanup.sh
chmod +x ~/.local/bin/cleanup.sh

echo 'YOUR_USERNAME ALL=(ALL) NOPASSWD: /bin/bash /home/YOUR_USERNAME/.local/bin/cleanup.sh' | sudo tee /etc/sudoers.d/cleanup
```

---

### NixOS

```bash
git clone https://github.com/yourusername/arch-cleanup.git
cd arch-cleanup
cp cleanup.sh ~/.local/bin/cleanup.sh
chmod +x ~/.local/bin/cleanup.sh
```

Add `libnotify` to your `environment.systemPackages` in `configuration.nix`, then run `sudo nixos-rebuild switch`.

For passwordless sudo, add to `security.sudo.extraRules` in your config:

```nix
security.sudo.extraRules = [{
  users = [ "YOUR_USERNAME" ];
  commands = [{
    command = "/bin/bash /home/YOUR_USERNAME/.local/bin/cleanup.sh";
    options = [ "NOPASSWD" ];
  }];
}];
```

---

### Void Linux

```bash
sudo xbps-install -S libnotify

git clone https://github.com/yourusername/arch-cleanup.git
cd arch-cleanup
cp cleanup.sh ~/.local/bin/cleanup.sh
chmod +x ~/.local/bin/cleanup.sh

echo 'YOUR_USERNAME ALL=(ALL) NOPASSWD: /bin/bash /home/YOUR_USERNAME/.local/bin/cleanup.sh' | sudo tee /etc/sudoers.d/cleanup
```

---

## Hyprland keybind

Add this to `~/.config/hypr/custom/keybinds.conf`:

```
bindd = Super, F2, Clean system cache, exec, sudo bash ~/.config/hypr/hyprland/scripts/cleanup.sh
```

Then reload Hyprland:

```bash
hyprctl reload
```

---

## Restoring packages

If something breaks after orphan removal, restore from the backup:

```bash
sudo pacman -S $(cat ~/.local/share/pkgbackup/pkglist.txt)
```

The backup is saved to `~/.local/share/pkgbackup/pkglist.txt` and overwritten on each run.

---

## Notification example

```
Cleaning... 14%   Saving package list backup...
Cleaning... 28%   Clearing pacman + AUR cache...
Cleaning... 42%   Removing orphaned dependencies...
Cleaning... 57%   Trimming pacman log...
Cleaning... 71%   Vacuuming systemd journal...
Cleaning... 85%   Clearing user cache...
Cleaning... 100%  Clearing pip cache...

Done — freed 2.3G
pacman cache    1.8G
journal          280M
pip cache         91M
user cache        54M
```

---

Made with ❤️

If you found this useful, please consider leaving a ⭐ — it helps a lot!
