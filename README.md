# CachyOS Ultimate Performance Setup

## Quick Start
```bash
./cachyos-tune.sh

Press Enter for dry-run mode, or type n for live mode.


---

Features

Installs CachyOS BORE kernel (if the repository provides it) and sets it as default

Preflight check before removing non-BORE kernels

System tuning:

sysctl

zram

journald

storage scheduler

TLP

cpupower


Gaming stack:

Gamemode (with valid configuration)

MangoHud

game helper command


Auto-detects Bash/Fish and configures accordingly

KDE tweaks only when Plasma is detected



---

Requirements

Run as real root:


su -

CachyOS kernel repository must be enabled so linux-cachyos-bore is available



---

After Install

Reboot to fully apply kernel and services.

Reload Fish configuration if needed:

fish -c 'source ~/.config/fish/config.fish'


---

Game Helper (game)

Launch Steam with Gamemode and MangoHud:

game steam

Run a native game:

game /path/to/GameBin

Steam (Proton) Launch Options:

gamemoderun mangohud %command%

Lutris:

Go to Preferences → System Options

Enable Feral Gamemode and MangoHud

For per-game:

Right-click the game → Configure → System Options → enable both




---

Verify

Check kernel:

uname -r | grep -i bore && echo OK || echo "Not running BORE kernel"

Check Gamemode and MangoHud:

systemctl status gamemoded.service --no-pager
mangohud glxgears

Check ZRAM:

swapon --show

Check TLP:

tlp-stat -s


---

Troubleshooting

BORE not found → enable CachyOS kernel repo and rerun

GPU shows as generic → ensure pciutils is installed (auto-installed), then rerun

Gamemode/MangoHud missing → run the script in live mode again

Non-KDE desktops → KDE tweaks are skipped automatically (KDE is recommended)



---

Logs

~/Desktop/cachyos-ultimate-setup.log
