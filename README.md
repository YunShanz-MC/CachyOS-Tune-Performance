# CachyOS Ultimate Performance Setup

## ✅ Quick Start

### Option 1: Direct Download via Curl (Recommended)
To get started quickly, copy and run the following command in your terminal:

```bash
curl -O https://raw.githubusercontent.com/YunShanz-MC/CachyOS-Tune-Performance/main/cachyos-tune.sh && chmod +x cachyos-tune.sh && ./cachyos-tune.sh
```

Press **Enter** for dry-run mode (preview only), or type **n** for live mode (apply changes).

**Note:** Make sure `curl` is installed (**`sudo pacman -S curl`** if needed). This downloads the main script directly without cloning the entire repository.

### Option 2: Clone Full Repository (For Development/Editing)
If you want to view or modify the source files:

```bash
git clone https://github.com/YunShanz-MC/CachyOS-Tune-Performance.git
cd CachyOS-Tune-Performance
chmod +x cachyos-tune.sh
./cachyos-tune.sh
```

**Prerequisites:** Install `git` if not available (`sudo pacman -S git`).

---

## ✅ Features
- Installs CachyOS BORE kernel (if available) and sets it as default  
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

---

## ✅ Requirements

### Run as Real Root
Copy and execute:

```bash
su -
```

### Enable CachyOS Kernel Repository
Make sure the CachyOS kernel repository is enabled so the `linux-cachyos-bore` package is available. Add to `/etc/pacman.conf`:

```
[cachyos]
Server = https://mirror.cachyos.org/repo/$arch
```

Then update your system:

```bash
sudo pacman -Syu
```

**Additional Requirements:**
- CachyOS or Arch Linux-based system
- Internet connection for package downloads
- At least 4GB RAM (optimized for low-end systems like Intel HD Graphics 500)
- Backup your system before running in live mode (recommended: Timeshift or BTRFS snapshot)

---

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

## ✅ Game Helper (`game`)

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

## ✅ Verify

### Check Kernel
Copy and run:

```bash
uname -r | grep -i bore && echo "✓ BORE kernel running" || echo "✗ Not running BORE kernel"
```

### Check Gamemode Service
Copy and execute:

```bash
systemctl status gamemoded.service --no-pager
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
echo "=== Gamemode ===" && systemctl is-active gamemoded.service && echo "✓ Active" || echo "✗ Inactive"
echo "=== ZRAM ===" && swapon --show | grep zram && echo "✓ Enabled" || echo "✗ Disabled"
echo "=== TLP ===" && tlp-stat -s | grep "TLP" && echo "✓ Running" || echo "✗ Not running"
```

---

## ✅ Troubleshooting
- **BORE kernel not found** → Enable CachyOS kernel repo in `/etc/pacman.conf` and run `sudo pacman -Syu linux-cachyos-bore`, then rerun script  
- **GPU shows generic** → Ensure `pciutils` is installed (`sudo pacman -S pciutils`, auto-installed by script), then rerun  
- **Gamemode/MangoHud missing** → Run the script in live mode again or manually install: `sudo pacman -S gamemode mangohud`  
- **Non-KDE desktops** → KDE tweaks are skipped automatically (KDE Plasma recommended for best results)  
- **Permission denied** → Make sure you're running as root (`su -`) and script has execute permissions (`chmod +x cachyos-tune.sh`)  
- **Network errors** → Check internet connection and CachyOS mirror availability  
- **Dual-boot issues** → Update GRUB after kernel changes: `sudo grub-mkconfig -o /boot/grub/grub.cfg`

---

## ✅ Logs

The log file is located at:

```
~/Desktop/cachyos-ultimate-setup.log
```

### View Logs
Copy and run:

```bash
cat ~/Desktop/cachyos-ultimate-setup.log
```

### Monitor Logs in Real-time
Copy and run (useful during script execution):

```bash
tail -f ~/Desktop/cachyos-ultimate-setup.log
```

### Clear Logs (After Successful Install)
Copy and run:

```bash
rm ~/Desktop/cachyos-ultimate-setup.log
```

---

## 📋 Additional Notes

- **Safety First:** Always backup important data before running in live mode
- **Hardware Compatibility:** Optimized for low-end systems (Intel HD Graphics 500, 4GB+ RAM)
- **Performance Gains:** Expect 10-30% improvement in gaming workloads with BORE kernel and optimizations
- **Support:** Report issues at [GitHub Issues](https://github.com/YunShanz-MC/CachyOS-Tune-Performance/issues)
- **License:** MIT License - Free to use, modify, and distribute

**Tested on:** CachyOS with kernel 6.17.1-1-cachyos-bore, Acer Aspire ES1-432 (Intel HD Graphics 500)
