<div align="center">

# CachyOS Ultimate Performance Setup

[![GitHub stars](https://img.shields.io/github/stars/YunShanz-MC/CachyOS-Tune-Performance?style=social)](https://github.com/YunShanz-MC/CachyOS-Tune-Performance/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/YunShanz-MC/CachyOS-Tune-Performance)](https://github.com/YunShanz-MC/CachyOS-Tune-Performance/issues)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CachyOS](https://img.shields.io/badge/Compatible-CachyOS-brightgreen)](https://cachyos.org)

**Automated optimization script for CachyOS gaming performance**  
Installs BORE kernel, system tweaks (sysctl, zram, TLP), and gaming stack (Gamemode, MangoHud) for low-end hardware.

</div>

<br>

## ☕ Support This Project

<div align="center">

**If this script boosted your FPS or made CachyOS smoother, please consider supporting the development!** 💖

### Quick Support Options
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?logo=buy-me-a-coffee&logoColor=black&style=flat)](https://www.buymeacoffee.com/YunShanzMC)

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Donate-yellow?style=for-the-badge&logo=ko-fi)](https://ko-fi.com/yunshanzmc)

**Why Donate?**
  
  🔧 Development time for new features
  
  🛠️ Bug fixes and community support
  
  ☁️ Server costs for CI/CD and package mirrors

  🖥️ help to upgrade my low-end hardware (Acer ES1-432, Intel HD 500)

**All contributions are voluntary and help keep this project free for everyone!** 🎮

</div>

---
---

## ✅ Quick Start

## 📌 Features
- Installs CachyOS BORE kernel and sets it as default  
- Preflight check before removing non-BORE kernels  
- System tuning:
  - sysctl  
  - zram  
  - journald  
  - storage scheduler  
  - TLP  
  - cpupower  
- Gaming stack:
  - Gamemode (with valid config)  
  - MangoHud  
  - `game` helper command  
- Auto-detects Bash/Fish and configures accordingly  
- KDE tweaks only when Plasma is detected  

## 📌 Requirements

### Run as Real Root
Copy and execute:

```bash
su -
```
Then update your system:

```bash
sudo pacman -Syu
```

**Additional Requirements:**
- *⚠️Only Supported Grub Bootloader Not Supported rEFIn etc⚠️*
- CachyOS Arch Linux-based system
- Internet connection for package downloads
- At least 4GB RAM (optimized for low-end systems)
- Backup your system before running in live mode (recommended: Timeshift or BTRFS snapshot)

---

**Note:** Make sure **`curl`** is installed (**`sudo pacman -S curl`**) if needed. This downloads the main script directly without cloning the entire repository.

## ✅ Quick Start

### Option 1: Direct Download via Curl (Recommended)
To get started quickly, copy and run the following command in your terminal:

```bash
curl -O https://raw.githubusercontent.com/YunShanz-MC/CachyOS-Tune-Performance/main/cachyos-tune.sh && chmod +x cachyos-tune.sh && ./cachyos-tune.sh
```

Press **Enter** for dry-run mode (preview only), or type **n** for live mode (apply changes).

### Option 2: Clone Full Repository (For Development/Editing)
If you want to view or modify the source files:

**Prerequisites:** Install **`git`** if not available (**`sudo pacman -S git`**).

```bash
git clone https://github.com/YunShanz-MC/CachyOS-Tune-Performance.git
cd CachyOS-Tune-Performance
chmod +x cachyos-tune.sh
./cachyos-tune.sh
```

## ✅ After Install

Reboot to apply the kernel and services:

```bash
reboot
```

If using Fish shell and need to reload config, copy and run:

```bash
fish -c 'source ~/.config/fish/config.fish'
```

---

## 🎮 Game Helper (`game`)

### Launch Steam with Gamemode + MangoHud
Copy and execute:

```bash
game steam
```

### Run a Native Game
Copy and execute (replace `/path/to/GameBin` with your actual game binary path):

```bash
game /path/to/GameBin
```

**Example for a specific game:**
```bash
game /opt/minecraft/MinecraftLauncher
```

### Steam (Proton) Launch Options

In Steam, right-click a game → Properties → Set Launch Options:

```bash
gamemoderun mangohud %command%
```

### Lutris Configuration
- Go to **Preferences → System Options**
- Enable **Feral Gamemode** and **MangoHud**

For individual games:
- Right-click game → **Configure → System Options** → enable both

---

## ☑️ Verify

### Check Kernel
Copy and run:

```bash
uname -r | grep -i bore && echo "✓ BORE kernel running" || echo "✗ Not running BORE kernel"
```

### Test MangoHud
Copy and run (should show FPS overlay):

```bash
mangohud glxgears
```

### Check ZRAM
Copy and run:

```bash
swapon --show
```

Expected output should show zram device (e.g., `/dev/zram0`).

### Check TLP Status
Copy and execute:

```bash
tlp-stat -s
```

### Full System Verification
Copy and run this comprehensive check:

```bash
echo "=== Kernel ===" && uname -r | grep -i bore && echo "✓ BORE kernel" || echo "✗ Standard kernel"
echo "=== ZRAM ===" && swapon --show | grep zram && echo "✓ Enabled" || echo "✗ Disabled"
echo "=== TLP ===" && tlp-stat -s | grep "TLP" && echo "✓ Running" || echo "✗ Not running"
```

---

## ℹ️ Troubleshooting
- **BORE kernel not found** → Enable CachyOS kernel repo in `/etc/pacman.conf` and run `sudo pacman -Syu linux-cachyos-bore`, then rerun script  
- **GPU shows generic** → Ensure `pciutils` is installed (`sudo pacman -S pciutils`, auto-installed by script), then rerun  
- **Gamemode/MangoHud missing** → Run the script in live mode again or manually install: `sudo pacman -S gamemode mangohud`  
- **Non-KDE desktops** → KDE tweaks are skipped automatically (KDE Plasma recommended for best results)  
- **Permission denied** → Make sure you're running as root (`su -`) and script has execute permissions (`chmod +x cachyos-tune.sh`)  
- **Network errors** → Check internet connection and CachyOS mirror availability  
- **Dual-boot issues** → Update GRUB after kernel changes: `sudo grub-mkconfig -o /boot/grub/grub.cfg`

---

## 📝 Logs

The log file is located at:

```
~/Desktop/cachyos-ultimate-setup.log
```

### 🔎 View Logs
Copy and run:

```bash
cat ~/Desktop/cachyos-ultimate-setup.log
```

---

## 📋 Additional Notes

- **Safety First:** Always backup important data before running in live mode
- **Performance Gains:** Expect 10-30% improvement in gaming workloads with BORE kernel and optimizations
- **Support:** Report issues at [GitHub Issues](https://github.com/YunShanz-MC/CachyOS-Tune-Performance/issues)
- **License:** MIT License - Free to use, modify, and distribute
- **Tested on:** Acer Aspire ES1-432 (Intel HD Graphics 500)
