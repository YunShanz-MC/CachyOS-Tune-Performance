# CachyOS Ultimate Performance Setup

## ✅ Quick Start

To get started, copy and run the following command in your terminal:

```bash
curl -O https://raw.githubusercontent.com/yourusername/cachyos-ultimate-setup/main/cachyos-tune.sh && chmod +x cachyos-tune.sh && ./cachyos-tune.sh
```

Press **Enter** for dry-run mode, or type **n** for live mode.

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

To run as real root, copy and execute:

```bash
su -
```

Make sure the CachyOS kernel repository is enabled so the `linux-cachyos-bore` package is available.

---

## ✅ After Install

Reboot to apply the kernel and services.

If using Fish shell and need to reload config, copy and run:

```bash
fish -c 'source ~/.config/fish/config.fish'
```

---

## ✅ Game Helper (`game`)

To launch Steam with Gamemode + MangoHud, copy and execute:

```bash
game steam
```

To run a native game, copy and execute (replace `/path/to/GameBin` with your actual game binary path):

```bash
game /path/to/GameBin
```

### Steam (Proton) Launch Options:

In Steam, set the launch options to:

```bash
gamemoderun mangohud %command%
```

### Lutris:
- Go to **Preferences → System Options**
- Enable **Feral Gamemode** and **MangoHud**

Per-game:
- Right-click game → **Configure → System Options** → enable both

---

## ✅ Verify

To check the kernel, copy and run:

```bash
uname -r | grep -i bore && echo OK || echo "Not running BORE kernel"
```

To check Gamemode and MangoHud, copy and execute these commands one by one:

```bash
systemctl status gamemoded.service --no-pager
```

```bash
mangohud glxgears
```

To check ZRAM, copy and run:

```bash
swapon --show
```

To check TLP, copy and execute:

```bash
tlp-stat -s
```

---

## ✅ Troubleshooting
- BORE not found → enable CachyOS kernel repo and rerun  
- GPU shows generic → ensure `` is installed (auto-installed), then rerun  
- Gamemode/MangoHud missing → run the script in live mode again  
- Non-KDE desktops → KDE tweaks are skipped automatically (KDE recommended)

---

## ✅ Logs

The log file is located at:

```
~/Desktop/cachyos-ultimate-setup.log
```

To view it, you can copy and run:

```bash
cat ~/Desktop/cachyos-ultimate-setup.log
```
