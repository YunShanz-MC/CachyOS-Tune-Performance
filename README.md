# CachyOS Ultimate Performance Setup

## ✅ Quick Start
\`\`\`bash
./cachyos-tune.sh
\`\`\`
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
  - \`game\` helper command  
- Auto-detects Bash/Fish and configures accordingly  
- KDE tweaks only when Plasma is detected  

---

## ✅ Requirements
Run as real root:
\`\`\`bash
su -
\`\`\`

Make sure the CachyOS kernel repository is enabled so the \`linux-cachyos-bore\` package is available.

---

## ✅ After Install
Reboot to apply the kernel and services.

Reload Fish config if needed:
\`\`\`bash
fish -c 'source ~/.config/fish/config.fish'
\`\`\`

---

## ✅ Game Helper (\`game\`)

Launch Steam with Gamemode + MangoHud:
\`\`\`bash
game steam
\`\`\`

Run a native game:
\`\`\`bash
game /path/to/GameBin
\`\`\`

### Steam (Proton) Launch Options:
\`\`\`bash
gamemoderun mangohud %command%
\`\`\`

### Lutris:
- Go to **Preferences → System Options**
- Enable **Feral Gamemode** and **MangoHud**

Per-game:
- Right-click game → **Configure → System Options** → enable both

---

## ✅ Verify

Check kernel:
\`\`\`bash
uname -r | grep -i bore && echo OK || echo "Not running BORE kernel"
\`\`\`

Check Gamemode and MangoHud:
\`\`\`bash
systemctl status gamemoded.service --no-pager
mangohud glxgears
\`\`\`

Check ZRAM:
\`\`\`bash
swapon --show
\`\`\`

Check TLP:
\`\`\`bash
tlp-stat -s
\`\`\`

---

## ✅ Troubleshooting
- BORE not found → enable CachyOS kernel repo and rerun  
- GPU shows generic → ensure \`pciutils\` is installed (auto-installed), then rerun  
- Gamemode/MangoHud missing → run the script in live mode again  
- Non-KDE desktops → KDE tweaks are skipped automatically (KDE recommended)

---

## ✅ Logs
\`\`\`
~/Desktop/cachyos-ultimate-setup.log
\`\`\`
