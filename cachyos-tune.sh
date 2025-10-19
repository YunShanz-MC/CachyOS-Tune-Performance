#!/bin/bash

# cachyos-tune.sh - ULTIMATE CachyOS Performance (BORE + Gaming Optimized)

# Auto-Performance Mode - No Prompts, Max FPS Everywhere

# Multi-Shell Compatible

set -euo pipefail

# Shebang check

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then

	echo -e "${RED}${E_ERR} Error: Requires Bash 4+.${RESET}"
	exit 1

fi

# Colors

RED="\e[31m"
YELLOW="\e[33m"
GREEN="\e[32m"
CYAN="\e[36m"
RESET="\e[0m"

E_OK="✔️"
E_WARN="⚠️"
E_ERR="🚫"
E_USER="👤"
E_PROC="🔄"
E_ASK="❓"

log_ok() { echo -e "${GREEN}${E_OK} $1${RESET}"; }

log_warn() { echo -e "${YELLOW}${E_WARN} $1${RESET}"; }

log_err() { echo -e "${RED}${E_ERR} $1${RESET}"; }

# Defaults & CLI flags

DRYRUN=false

ASSUME_YES=false

FLAG_SET=false

FULL_UPGRADE=false

DEBLOAT=false

for arg in "$@"; do

	case "$arg" in

	--dry-run)

		DRYRUN=true
		FLAG_SET=true
		;;

	--live)

		DRYRUN=false
		FLAG_SET=true
		;;

	-y | --yes)

		ASSUME_YES=true
		;;

	--full-upgrade)

		FULL_UPGRADE=true
		;;

	--debloat)

		DEBLOAT=true
		;;

		# (AUR is always enabled by default now; no flag parsing needed)

	esac

done

# Root check (su - only)

if [ "$(id -u)" -ne 0 ]; then

	log_err "Error: run as real root su -"
	exit 1

fi

if [ -n "${SUDO_USER-}" ] || [ -n "${SUDO_COMMAND-}" ]; then

	log_err "Error: do NOT run via sudo. Use su -"
	exit 1

fi

# Detect user

USERNAME=$(logname 2>/dev/null || awk -F: '$3>=1000 && $1!="nobody" {print $1; exit}' /etc/passwd)

if [ -z "$USERNAME" ] || [ "$USERNAME" = "root" ]; then

	log_err "Error: could not detect non-root user"
	exit 1

fi

USER_HOME=$(eval echo "~$USERNAME")

if [ ! -d "$USER_HOME" ]; then

	log_err "Error: user home not found: $USER_HOME"
	exit 1

fi

# GLOBAL SHELL CONFIG PATHS (FIX: Define early to avoid undefined errors)

BASHRC="$USER_HOME/.bashrc"

ZSHRC="$USER_HOME/.zshrc"

FISHCFG="$USER_HOME/.config/fish/config.fish"

DEFAULT_CONFIG="$BASHRC"

# Setup logging

LOG="$USER_HOME/Desktop/cachyos-ultimate-setup.log"

mkdir -p "$USER_HOME/Desktop"

touch "$LOG"

chown "$USERNAME":"$USERNAME" "$LOG" 2>/dev/null || true

exec > >(tee -a "$LOG") 2>&1

echo -e "${CYAN}${E_PROC} === CACHYOS ULTIMATE PERFORMANCE SETUP === ($(date))${RESET}"

echo -e "${CYAN}${E_USER} User: ${USERNAME} (${USER_HOME})${RESET}"

echo

# Desktop Environment detection (for conditional tweaks)

CURRENT_DE="${XDG_CURRENT_DESKTOP-}${DESKTOP_SESSION-}"

PLASMA=false

# KDE/Plasma detection heuristic: env vars, loginctl, then binaries/config files
if echo "$CURRENT_DE" | grep -qi "plasma\|kde"; then
	PLASMA=true
else
	# Try via loginctl if available
	if command -v loginctl >/dev/null 2>&1; then
		ACTIVE_SESS=$(loginctl | awk 'NR==2{print $1}')
		if [ -n "$ACTIVE_SESS" ]; then
			DESKTOP_PROP=$(loginctl show-session "$ACTIVE_SESS" -p Desktop 2>/dev/null | cut -d= -f2)
			TYPE_PROP=$(loginctl show-session "$ACTIVE_SESS" -p Type 2>/dev/null | cut -d= -f2)
			if echo "$DESKTOP_PROP$TYPE_PROP" | grep -qi "plasma\|kde"; then
				PLASMA=true
			fi
		fi
	fi
	# Final fallback: check Plasma binaries/config presence
	if [ "$PLASMA" = false ]; then
		if command -v plasmashell >/dev/null 2>&1 || command -v kwin_x11 >/dev/null 2>&1 || [ -f "$USER_HOME/.config/kdeglobals" ] || [ -f "/etc/xdg/kwinrc" ]; then
			PLASMA=true
		fi
	fi
fi

# Dry-run selection: flags > TTY prompt > non-interactive default to dry-run

if [ "$FLAG_SET" = false ]; then

	if [ -t 0 ] && [ "$ASSUME_YES" = false ]; then

		echo -ne "${CYAN}${E_ASK} Dry-run mode (Y/n): ${RESET}"

		read -r DRY_ANSWER || DRY_ANSWER="y"

		DRY_ANSWER=${DRY_ANSWER:-y}

		if echo "$DRY_ANSWER" | grep -qi "^y"; then

			DRYRUN=true

			log_warn "DRY-RUN MODE — No changes will be applied"

		else

			DRYRUN=false

			log_ok "LIVE MODE — Maximum performance setup"

		fi

		# Debloat prompt (interactive default: skip)

		echo -ne "${CYAN}${E_ASK} Enable debloat (disable non-essential services)? (y/N): ${RESET}"

		read -r DEB_ANS || DEB_ANS="n"

		if echo "${DEB_ANS:-n}" | grep -qi '^y'; then

			DEBLOAT=true

			log_warn "Debloat enabled — non-essential services will be disabled"

		else

			DEBLOAT=false

			log_ok "Debloat skipped"

		fi

	else

		# non-interactive: default to safe dry-run unless --live provided

		DRYRUN=true

		log_warn "DRY-RUN MODE (non-interactive default)"

	fi

fi

echo

# Optional full system upgrade (before installs)

if [ "$FULL_UPGRADE" = true ]; then

	run_cmd "pacman -Syu --noconfirm"

	log_ok "System fully upgraded"

fi

# Hardware detection

TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')

CPU_CORES=$(nproc)

STORAGE_TYPE=$(lsblk -dno rota "$(findmnt -n -o SOURCE /)" 2>/dev/null || echo "0")

# Low-end detection

if [ "$TOTAL_RAM" -lt 4096 ] || [ "$CPU_CORES" -lt 4 ]; then

	LOW_END_MODE=true

	log_warn "LOW-END HARDWARE DETECTED — Extreme optimization enabled"

else

	LOW_END_MODE=false

fi

# GPU detection

if ! command -v lspci &>/dev/null; then

	run_cmd "pacman -S --noconfirm --needed pciutils" || pacman_retry -S --noconfirm --needed pciutils

fi

GPU="generic"

if command -v lspci &>/dev/null; then

	GPU_INFO=$(lspci -nnk 2>/dev/null | grep -EA3 'VGA|3D|Display' | tr 'A-Z' 'a-z')

	if echo "$GPU_INFO" | grep -q "\[8086:" || echo "$GPU_INFO" | grep -q "intel\|uhd\|iris"; then

		GPU="intel"
		log_ok "Intel GPU detected"

	elif echo "$GPU_INFO" | grep -q "\[10de:" || echo "$GPU_INFO" | grep -q "nvidia"; then

		GPU="nvidia"
		log_ok "NVIDIA GPU detected"

	elif echo "$GPU_INFO" | grep -q "\[1002:" || echo "$GPU_INFO" | grep -q "amd\|advanced micro devices\|ati\|radeon"; then

		GPU="amd"
		log_ok "AMD GPU detected"

	else

		GPU="generic"
		log_warn "Generic GPU - using Mesa"

	fi

else

	GPU="generic"
	log_warn "pciutils (lspci) not available; defaulting to generic"

fi

# Universal Shell Detection Function (FIX: Comprehensive multi-shell support)

detect_user_shell() {

	USER_SHELL=$(getent passwd "$USERNAME" | awk -F: '{print $7}' | xargs basename 2>/dev/null || echo "/bin/bash")

	case "$USER_SHELL" in

	*fish)

		IS_FISH=true

		IS_BASH=false

		IS_ZSH=false

		SHELL_CONFIG="$FISHCFG"

		SHELL_SYNTAX="fish"

		log_ok "User shell detected: fish"

		;;

	*zsh)

		IS_FISH=false

		IS_BASH=false

		IS_ZSH=true

		SHELL_CONFIG="$ZSHRC"

		SHELL_SYNTAX="zsh"

		log_ok "User shell detected: zsh"

		;;

	*bash | */sh | */dash)

		IS_FISH=false

		IS_BASH=true

		IS_ZSH=false

		SHELL_CONFIG="$DEFAULT_CONFIG"

		SHELL_SYNTAX="bash"

		log_ok "User shell detected: bash/sh"

		;;

	*)

		IS_FISH=false

		IS_BASH=true

		IS_ZSH=false

		SHELL_CONFIG="$DEFAULT_CONFIG"

		SHELL_SYNTAX="bash"

		log_warn "Unknown shell ($USER_SHELL), defaulting to bash"

		;;

	esac

}

# Call shell detection

detect_user_shell

# Helpers

pkg_installed() { pacman -Qi "$1" &>/dev/null; }

backup_if_exists() {

	t="$1"

	if [ -e "$t" ] && [ "$DRYRUN" = false ]; then

		ts=$(date +%Y%m%d%H%M%S)

		cp -a "$t" "${t}.bak.${ts}" && log_ok "Backup: ${t}"

	fi

}

run_cmd() {

	echo -e "${CYAN}[CMD]${RESET} $*"

	if [ "$DRYRUN" = true ]; then

		echo "[DRY-RUN] $*"

		return 0

	else

		if ! bash -c "$*"; then

			log_warn "Command failed (non-fatal): $*"

			return 1

		fi

	fi

}

run_su_user() {

	echo -e "${CYAN}[CMD - $USERNAME]${RESET} su - $USERNAME -c \"$*\""

	if [ "$DRYRUN" = true ]; then

		echo "[DRY-RUN] su - $USERNAME -c \"$*\""

	else

		su - "$USERNAME" -c "$*" || log_warn "User command failed: $*"

	fi

}

write_file() {

	p="$1"
	shift

	if [ "$DRYRUN" = true ]; then

		echo "[DRY-RUN] Would write $p"

		# Print all remaining arguments
		for arg in "$@"; do
			echo "$arg"
		done

	else

		backup_if_exists "$p"

		# Write all arguments to file
		printf "%s\n" "$@" >"$p"

		log_ok "Config written: $p"

	fi

}

append_file() {

	p="$1"
	shift
	c="$*"

	if [ "$DRYRUN" = true ]; then

		echo "[DRY-RUN] Would append to $p"

		echo "$c"

	else

		if [ -e "$p" ]; then

			backup_if_exists "$p"

		fi

		# Add newline only if file doesn't end with newline
		if [ -s "$p" ] && [ "$(tail -c1 "$p" | wc -l)" -eq 0 ]; then
			printf "\n%s\n" "$c" >>"$p"
		else
			printf "%s\n" "$c" >>"$p"
		fi

		log_ok "Config appended: $p"

	fi

}

# Helper: check command availability
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Retry utility with simple exponential backoff
retry_with_backoff() {
	local max_attempts=${1:-3}
	shift || true
	local sleep_s=1
	local attempt=1
	while [ $attempt -le $max_attempts ]; do
		if bash -lc "$*"; then
			return 0
		fi
		log_warn "Attempt $attempt failed — retrying in ${sleep_s}s: $*"
		sleep "$sleep_s"
		sleep_s=$((sleep_s * 2))
		attempt=$((attempt + 1))
	done
	log_warn "Command still failing after ${max_attempts} attempts: $*"
	return 1
}

# curl with retry wrapper
curl_retry() {
	local url="$1"
	local out="$2"
	retry_with_backoff 3 "curl -L --retry 3 --retry-delay 1 --fail -o '$out' '$url'"
}

# Trap error logging (show line number on error)
trap 'log_err "Error occurred at line $LINENO"' ERR

# pacman with retry wrapper
pacman_retry() {
	retry_with_backoff 3 "pacman $*" || true
}

# check if we can su to target user non-interactively
can_su_user() { su - "$USERNAME" -c true >/dev/null 2>&1; }

# Apply sysctl settings safely for the currently running kernel
apply_sysctl_safely() {
	log_ok "Applying supported sysctl settings for the current kernel..."
	# Read all .conf files, filter out comments/empty lines, and apply one-by-one.
	# This prevents errors from non-existent keys on the current kernel while leaving
	# the config files intact for the next boot with the BORE kernel.
	grep -rhvE '^\s*(#|$)' /etc/sysctl.d/ 2>/dev/null | while IFS= read -r line; do
		key=$(echo "$line" | cut -d'=' -f1 | tr -d '[:space:]')
		proc_path="/proc/sys/${key//./\/}"
		if [ -e "$proc_path" ]; then
			# Apply the setting, redirecting errors to null to be safe
			sysctl "$line" >/dev/null 2>&1 || true
		fi
	done
	log_ok "Live sysctl settings applied. Full configuration will be active on next boot."
	return 0
}

ensure_cachyos_kernel_repo() {

	# Fix pacman.conf corruption first
	if grep -q "\\n\[cachyos-kernel\]" /etc/pacman.conf 2>/dev/null; then
		log_warn "Fixing pacman.conf corruption..."
		backup_if_exists "/etc/pacman.conf"
		# Remove lines with literal \n character
		sed -i '/\\n\[cachyos-kernel\]/d' /etc/pacman.conf
		run_cmd "pacman -Syy"
		log_ok "pacman.conf fixed"
	fi

	# Install keyring/mirrorlist if missing

	if [ ! -f "/etc/pacman.d/cachyos-mirrorlist" ]; then

		run_cmd "pacman -S --noconfirm --needed cachyos-keyring cachyos-mirrorlist || true" || pacman_retry -S --noconfirm --needed cachyos-keyring cachyos-mirrorlist || true

	fi

	# Enable repos in pacman.conf if not present

	if ! grep -q "^\[cachyos\]" /etc/pacman.conf 2>/dev/null; then

		backup_if_exists "/etc/pacman.conf"

		append_file "/etc/pacman.conf" "[cachyos]"

		append_file "/etc/pacman.conf" "Include = /etc/pacman.d/cachyos-mirrorlist"

	fi

	if ! grep -q "^\[cachyos-kernel\]" /etc/pacman.conf 2>/dev/null; then

		append_file "/etc/pacman.conf" "[cachyos-kernel]"

		append_file "/etc/pacman.conf" "Include = /etc/pacman.d/cachyos-mirrorlist"

	fi

	# Refresh databases with better error handling
	if ! run_cmd "pacman -Sy --noconfirm"; then
		log_warn "Normal sync failed, trying force refresh..."
		if ! run_cmd "pacman -Syy --noconfirm"; then
			log_warn "Force refresh failed, continuing with available repos..."
		fi
	fi

}

# Kernel: cleanup & BORE install

echo -e "${CYAN}${E_PROC} 1. KERNEL OPTIMIZATION (BORE ONLY)${RESET}"

# Get all installed kernels

INSTALLED_KERNELS=($(pacman -Q | grep '^linux-' | awk '{print $1}'))

BORE_INSTALLED=false

KERNELS_TO_REMOVE=()

for kernel in "${INSTALLED_KERNELS[@]}"; do

	if [[ "$kernel" == *"cachyos-bore"* ]]; then

		BORE_INSTALLED=true

		log_ok "BORE kernel found: $kernel"

	else

		KERNELS_TO_REMOVE+=("$kernel")

	fi

done

# Auto-install BORE (performance best)

if [ "$BORE_INSTALLED" = false ]; then

	ensure_cachyos_kernel_repo

	# Try to install BORE kernel with better error handling
	if run_cmd "pacman -S --noconfirm linux-cachyos-bore linux-cachyos-bore-headers" || pacman_retry -S --noconfirm linux-cachyos-bore linux-cachyos-bore-headers; then
		log_ok "BORE kernel installed (best for gaming)"
		BORE_INSTALLED=true
	else
		log_warn "Failed to install BORE kernel, trying alternative approach..."
		# Try installing without headers first
		if run_cmd "pacman -S --noconfirm linux-cachyos-bore" || pacman_retry -S --noconfirm linux-cachyos-bore; then
			log_ok "BORE kernel installed (without headers)"
			BORE_INSTALLED=true
		else
			log_err "Could not install BORE kernel. Please check repository configuration."
			exit 1
		fi
	fi

fi

# Ensure GRUB is available (CRITICAL FIX)

if ! command -v grub-mkconfig &>/dev/null; then

	log_warn "GRUB tools missing - installing..."

	run_cmd "pacman -S --noconfirm --needed grub efibootmgr os-prober" || pacman_retry -S --noconfirm --needed grub efibootmgr os-prober || {
		log_err "Failed to install GRUB tools. Please install manually: sudo pacman -S grub efibootmgr"
		exit 1
	}

	# Enable OS prober for Windows dual-boot

	if grep -q '^#GRUB_DISABLE_OS_PROBER=false' /etc/default/grub; then

		run_cmd "sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub"

	elif ! grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub; then

		run_cmd "echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub"

	fi

	# Install GRUB EFI (CachyOS standard: /boot, not /boot/efi)

	if [ -d "/sys/firmware/efi" ]; then

		# UEFI system - CachyOS mounts EFI to /boot

		if mountpoint -q /boot; then

			run_cmd "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"

			log_ok "GRUB EFI installed to /boot (UEFI)"

		else

			log_warn "Boot partition not mounted - attempting auto-mount"

			EFI_PART=$(blkid -t TYPE="vfat" -o device 2>/dev/null | head -1)

			if [ -n "$EFI_PART" ]; then

				run_cmd "mount $EFI_PART /boot"

				run_cmd "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"

				log_ok "EFI partition mounted and GRUB installed"

			else

				log_err "EFI partition not found - manual mount required"

				log_err "Run: sudo mount /dev/nvme0n1p1 /boot (adjust partition)"

				exit 1

			fi

		fi

	else

		# BIOS legacy (rare for modern systems)

		log_warn "BIOS system detected - GRUB install requires disk device"

		log_warn "Edit script: replace /dev/sda with your disk (lsblk to check)"

		run_cmd "grub-install --target=i386-pc /dev/sda" # CHANGE /dev/sda to your disk!

	fi

	log_ok "GRUB bootloader setup complete"

else

	log_ok "GRUB already installed"

	# Ensure OS prober enabled

	if ! grep -q "GRUB_DISABLE_OS_PROBER=false" /etc/default/grub 2>/dev/null; then

		run_cmd "sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub"

	fi

fi

# Update GRUB

run_cmd "grub-mkconfig -o /boot/grub/grub.cfg"

# Set default kernel if grubby available

if command -v grubby &>/dev/null; then

	run_cmd "grubby --set-default /boot/vmlinuz-linux-cachyos-bore"

	log_ok "BORE set as default kernel"

fi

# Preflight checks before removing other kernels

PRE_OK=true

if [ -f "/boot/vmlinuz-linux-cachyos-bore" ]; then

	log_ok "BORE kernel image present"

else

	log_warn "BORE kernel image missing"

	PRE_OK=false

fi

if [ -f "/boot/initramfs-linux-cachyos-bore.img" ] || [ -f "/boot/initramfs-linux-cachyos-bore-fallback.img" ]; then

	log_ok "BORE initramfs present"

else

	run_cmd "mkinitcpio -P"

	if [ -f "/boot/initramfs-linux-cachyos-bore.img" ] || [ -f "/boot/initramfs-linux-cachyos-bore-fallback.img" ]; then

		log_ok "BORE initramfs generated"

	else

		log_warn "BORE initramfs missing"

		PRE_OK=false

	fi

fi

if grep -q "linux-cachyos-bore" /boot/grub/grub.cfg 2>/dev/null; then

	log_ok "GRUB entry for BORE exists"

else

	log_warn "GRUB entry for BORE not found - regenerating"

	run_cmd "update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg"

	if grep -q "linux-cachyos-bore" /boot/grub/grub.cfg 2>/dev/null; then

		log_ok "GRUB entry regenerated successfully"

	else

		log_warn "GRUB entry still missing - manual fix may be needed"

		PRE_OK=false

	fi

fi

if command -v dkms &>/dev/null; then

	run_cmd "dkms status || true"

	log_ok "DKMS status checked"

fi

# Auto-remove other kernels (performance focus) only if preflight passed

if [ ${#KERNELS_TO_REMOVE[@]} -gt 0 ]; then

	if [ "$DRYRUN" = true ]; then

		echo "[DRY-RUN] Would remove: ${KERNELS_TO_REMOVE[*]}"

	else

		if [ "$PRE_OK" = true ]; then

			log_ok "Starting BORE ONLY kernel cleanup..."

			# Smart kernel removal: handle dependencies properly
			log_ok "Starting smart kernel cleanup..."

			# Remove headers first (they depend on kernels) - but skip critical ones
			HEADER_KERNELS=()
			for kernel in "${KERNELS_TO_REMOVE[@]}"; do
				if [[ "$kernel" == *"-headers" ]]; then
					# Skip critical headers that are system dependencies
					case "$kernel" in
					linux-api-headers)
						log_warn "Skipping critical headers: $kernel (required by glibc)"
						continue
						;;
					*)
						HEADER_KERNELS+=("$kernel")
						;;
					esac
				fi
			done

			# Remove safe headers first
			for header in "${HEADER_KERNELS[@]}"; do
				if pacman -Qi "$header" &>/dev/null; then
					run_cmd "pacman -Rns --noconfirm $header"
					log_ok "Removed headers: $header"
				fi
			done

			# Remove kernels (excluding critical ones)
			for kernel in "${KERNELS_TO_REMOVE[@]}"; do
				# Skip critical packages that are system dependencies
				case "$kernel" in
				linux-api-headers)
					log_warn "Skipping critical package: $kernel (required by glibc)"
					continue
					;;
				linux-firmware*)
					log_warn "Skipping firmware package: $kernel"
					continue
					;;
				esac

				# Skip headers (already processed)
				if [[ "$kernel" == *"-headers" ]]; then
					continue
				fi

				# Remove kernel
				if pacman -Qi "$kernel" &>/dev/null; then
					run_cmd "pacman -Rns --noconfirm $kernel"
					log_ok "Removed kernel: $kernel"
				fi
			done

			# Ensure linux-firmware is available
			if ! pacman -Qi linux-firmware &>/dev/null; then
				log_warn "Installing unified linux-firmware..."
				run_cmd "pacman -S --noconfirm linux-firmware" || pacman_retry -S --noconfirm linux-firmware
				log_ok "Unified linux-firmware installed"
			fi

			log_ok "BORE ONLY cleanup complete - ${#KERNELS_TO_REMOVE[@]} total packages processed"

			log_ok "Active kernel: $(uname -r)"

			log_ok "Default kernel: BORE (GRUB updated)"

			log_warn "Reboot is required to boot into the new BORE kernel."
			log_warn "Some optimizations (like sysctl) will be fully applied after reboot."

		else

			log_warn "Preflight failed; skipping kernel removal to avoid unbootable system"

		fi

	fi

fi

# BORE-specific optimizations

backup_if_exists "/etc/sysctl.d/97-bore.conf"

write_file "/etc/sysctl.d/97-bore.conf" \
	"# BORE Ultimate Gaming Optimizations" \
	"kernel.sched_autogroup_enabled=1" \
	"kernel.sched_child_runs_first=1" \
	"kernel.sched_latency_ns=12000000" \
	"kernel.sched_migration_cost_ns=5000000" \
	"kernel.sched_min_granularity_ns=4000000" \
	"kernel.sched_wakeup_granularity_ns=2000000" \
	"kernel.sched_tunable_scaling=1" \
	"kernel.sched_boost=1" \
	"kernel.sched_is_big_little=0" \
	"kernel.sched_energy_aware=0" \
	"" \
	"# Gaming priority" \
	"kernel.sched_latency_ns=8000000"

# Low-end BORE tweaks

if [ "$LOW_END_MODE" = true ]; then

	append_file "/etc/sysctl.d/97-bore.conf" "# Low-end hardware"

	append_file "/etc/sysctl.d/97-bore.conf" "kernel.sched_latency_ns=6000000"

	append_file "/etc/sysctl.d/97-bore.conf" "kernel.sched_min_granularity_ns=1500000"

	log_ok "BORE low-end optimizations applied"

fi

if [ "$DRYRUN" = false ]; then

	apply_sysctl_safely

	log_ok "BORE scheduler loaded - maximum responsiveness"

fi

# Core packages & GPU drivers

echo -e "${CYAN}${E_PROC} 2. CORE PACKAGES & GPU OPTIMIZATION${RESET}"

# Essential packages (performance focus)

CORE_PACKAGES=(flatpak perl gamemode mangohud tlp cpupower pacman-contrib cachyos-settings cachyos-ksm-settings linux-headers)

MISSING=()

for pkg in "${CORE_PACKAGES[@]}"; do

	if ! pkg_installed "$pkg"; then

		MISSING+=("$pkg")

	fi

done

if [ ${#MISSING[@]} -gt 0 ]; then

	# Handle TLP vs power-profiles-daemon conflict
	if [[ " ${MISSING[*]} " =~ " tlp " ]] && pkg_installed "power-profiles-daemon"; then
		log_warn "Removing power-profiles-daemon (conflicts with TLP)"
		run_cmd "pacman -Rns --noconfirm power-profiles-daemon"
	fi

	run_cmd "pacman -S --noconfirm --needed ${MISSING[*]}" || pacman_retry -S --noconfirm --needed ${MISSING[*]}

	log_ok "Core packages installed"

fi

# GPU drivers (auto-optimized)

case "$GPU" in

nvidia)

	run_cmd "pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils vulkan-icd-loader lib32-vulkan-icd-loader" || pacman_retry -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils vulkan-icd-loader lib32-vulkan-icd-loader

	# NVIDIA performance mode

	if [ "$DRYRUN" = false ]; then

		nvidia-smi -pm 1 &>/dev/null || true

		log_ok "NVIDIA persistence mode enabled"

	fi

	;;

amd)

	run_cmd "pacman -S --noconfirm --needed mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon amdvlk lib32-amdvlk" || pacman_retry -S --noconfirm --needed mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon amdvlk lib32-amdvlk

	# AMD P-State performance

	write_file "/etc/modprobe.d/amd_pstate.conf" "options amd_pstate=active"

	log_ok "AMD drivers + P-State performance enabled"

	;;

intel)

	run_cmd "pacman -S --noconfirm --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver libva-intel-driver" || pacman_retry -S --noconfirm --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver libva-intel-driver

	# Intel low-end tweaks

	if [ "$LOW_END_MODE" = true ]; then

		CONFIG_FILE=$([ "$IS_FISH" = true ] && echo "$FISHCFG" || echo "$BASHRC")

		run_su_user "grep -q 'MESA_NO_DXT1=1' \"$CONFIG_FILE\" 2>/dev/null || echo 'export MESA_NO_DXT1=1' >> \"$CONFIG_FILE\""

		run_su_user "grep -q 'LIBGL_DRI3_DISABLE=1' \"$CONFIG_FILE\" 2>/dev/null || echo 'export LIBGL_DRI3_DISABLE=1' >> \"$CONFIG_FILE\""

		log_ok "Intel low-end Mesa optimizations"

	fi

	log_ok "Intel GPU optimized"

	;;

*)

	run_cmd "pacman -S --noconfirm --needed mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader" || pacman_retry -S --noconfirm --needed mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader

	log_ok "Generic Mesa/Vulkan installed"

	;;

esac

# CachyOS gaming meta (universal performance)

run_cmd "pacman -S --noconfirm cachyos-gaming-meta || true" || pacman_retry -S --noconfirm cachyos-gaming-meta || true
run_cmd "pacman -S --noconfirm lutris || true" || pacman_retry -S --noconfirm lutris || true
run_cmd "pacman -S --noconfirm heroic-games-launcher || true" || pacman_retry -S --noconfirm heroic-games-launcher || true

log_ok "Gaming meta packages installed"

# Power management (TLP)

echo -e "${CYAN}${E_PROC} 3. POWER MANAGEMENT (TLP PERFORMANCE)${RESET}"

# Auto-remove PPD, install TLP (gaming priority)

if pkg_installed power-profiles-daemon; then

	run_cmd "systemctl disable --now power-profiles-daemon.service"

	run_cmd "pacman -Rns --noconfirm power-profiles-daemon"

	log_ok "Power Profiles Daemon removed (conflicts with TLP)"

fi

# TLP gaming config

backup_if_exists "/etc/tlp.conf"

write_file "/etc/tlp.conf" "# TLP Gaming Performance Configuration

CPU_SCALING_GOVERNOR_ON_AC=\"performance\"

CPU_SCALING_GOVERNOR_ON_BAT=\"performance\"

CPU_ENERGY_PERF_POLICY_ON_AC=\"performance\"

CPU_ENERGY_PERF_POLICY_ON_BAT=\"performance\"

CPU_MIN_PERF_ON_AC=100

CPU_MAX_PERF_ON_AC=100

CPU_MIN_PERF_ON_BAT=80

CPU_MAX_PERF_ON_BAT=100

CPU_BOOST_ON_AC=1

CPU_BOOST_ON_BAT=1


# NVIDIA/AMD GPU

RADEON_POWER_PROFILE_ON_AC=\"high\"

RADEON_POWER_PROFILE_ON_BAT=\"low\"

NVIDIA_POWER_METHOD=\"auto\"


# Disk & I/O

DISK_IDLE_SECS_ON_AC=\"0\"

DISK_DEVICES=\"nvme0n1 sda\"


# Runtime PM

RUNTIME_PM_ON_AC=\"auto\"

RUNTIME_PM_ON_BAT=\"auto\"


# Sound

SOUND_POWER_SAVE_ON_AC=0

SOUND_POWER_SAVE_ON_BAT=1


# USB

USB_AUTOSUSPEND=1"

run_cmd "systemctl enable --now tlp.service"

run_cmd "tlp start"

log_ok "TLP configured for maximum gaming performance"

# CPU power (performance governor)

run_cmd "sed -i 's/^#governor=.*$/governor=\"performance\"/' /etc/default/cpupower"

run_cmd "systemctl enable --now cpupower.service"

log_ok "CPU performance governor enabled"

# Package manager

echo -e "${CYAN}${E_PROC} 4. PACKAGE MANAGER PREP${RESET}"

# Install base-devel & git

run_cmd "pacman -S --noconfirm --needed base-devel git go" || pacman_retry -S --noconfirm --needed base-devel git go

# Install yay (AUR helper)
echo -e "${CYAN}${E_PROC} 4b. OPTIONAL AUR HELPER (YAY)${RESET}"
if ! command -v yay &>/dev/null; then
	log_warn "Installing yay AUR helper (optional)..."
	AUR_DIR="$USER_HOME/.cache/aur/yay"
	if can_su_user && run_su_user "rm -rf '$AUR_DIR' && mkdir -p '$AUR_DIR' && git clone https://aur.archlinux.org/yay.git '$AUR_DIR'"; then
		if run_su_user "cd '$AUR_DIR' && makepkg -si --noconfirm"; then
			run_cmd "rm -rf '$AUR_DIR'"
			log_ok "yay AUR helper installed"
		else
			log_warn "makepkg -si failed — trying install built package via pacman -U"
			if run_su_user "cd '$AUR_DIR' && ls *.pkg.tar.* >/dev/null 2>&1"; then
				PKG_PATH=$(su - "$USERNAME" -c "cd '$AUR_DIR' && ls -t *.pkg.tar.* | head -1")
				if [ -n "$PKG_PATH" ]; then
					run_cmd "pacman -U --noconfirm '$AUR_DIR/$PKG_PATH'" || pacman_retry -U --noconfirm "$AUR_DIR/$PKG_PATH"
				fi
			fi
			run_cmd "rm -rf '$AUR_DIR'" || true
		fi
	else
		log_warn "Cannot su to user — trying pacman package for yay"
		run_cmd "pacman -S --noconfirm yay" || pacman_retry -S --noconfirm yay || log_warn "Could not install yay"
	fi
else
	log_ok "yay already installed"
fi

# Flathub (guard flatpak presence)
if command -v flatpak &>/dev/null; then
	run_su_user "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
	log_ok "Flathub repository added"
else
	log_warn "Flatpak not installed; skipping Flathub add"
fi

# Sysctl performance
echo -e "${CYAN}${E_PROC} 5. ULTIMATE SYSCTL PERFORMANCE${RESET}"

backup_if_exists "/etc/sysctl.d/99-ultimate.conf"
write_file "/etc/sysctl.d/99-ultimate.conf" \
	"# ULTIMATE GAMING PERFORMANCE (BORE + Low-Latency)
# Memory (low-end optimized)
vm.swappiness=$([ "$LOW_END_MODE" = true ] && echo "1" || echo "10")
vm.vfs_cache_pressure=$([ "$LOW_END_MODE" = true ] && echo "200" || echo "50")
vm.min_free_kbytes=$([ "$TOTAL_RAM" -lt 2048 ] && echo "16384" || echo "65536")
vm.max_map_count=1048576
vm.compact_unevictable_allowed=1
vm.dirty_ratio=15
vm.dirty_background_ratio=5

# Filesystem
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=$([ "$LOW_END_MODE" = true ] && echo "8192" || echo "524288")
fs.file-max=2097152

# Network (gaming low-latency)
net.core.default_qdisc=fq_codel
net.core.netdev_max_backlog=4096
net.ipv4.tcp_keepalive_time=120
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_timestamps=1

# Kernel
kernel.nmi_watchdog=0
kernel.printk=3 3 3 3
kernel.panic=10
kernel.sched_autogroup_enabled=1

# Low-end specific
$([ "$LOW_END_MODE" = true ] && echo "vm.compact_unevictable_allowed=0" || echo "")
$([ "$LOW_END_MODE" = true ] && echo "kernel.sched_energy_aware=0" || echo "")"

if [ "$DRYRUN" = false ]; then
	apply_sysctl_safely
	log_ok "Ultimate sysctl tweaks loaded"
fi

# ZRAM & journal
echo -e "${CYAN}${E_PROC} 6. MEMORY & STORAGE OPTIMIZATION${RESET}"

# ZRAM (aggressive for low-end)
if ! pkg_installed zram-generator; then
	run_cmd "pacman -S --noconfirm zram-generator" || pacman_retry -S --noconfirm zram-generator
fi

# Disable conflicting manager if present
run_cmd "systemctl is-active --quiet systemd-swap.service && systemctl disable --now systemd-swap.service || true"

# Ensure kernel module available
run_cmd "modprobe zram || true"

backup_if_exists "/etc/systemd/zram-generator.conf"
ZRAM_SIZE=$([ "$LOW_END_MODE" = true ] && echo "ram / 1.33" || echo "ram / 2")
write_file "/etc/systemd/zram-generator.conf" \
	"[zram0]
zram-size = $ZRAM_SIZE
compression-algorithm = zstd"

if [ "$DRYRUN" = false ]; then
	run_cmd "systemctl daemon-reload"
	# Try common unit names
	run_cmd "(systemctl enable --now systemd-zram-setup@zram0.service || systemctl enable --now systemd-zram-setup.service || true)"
	# Verify activation; fallback to manual if needed
	if [ -e /dev/zram0 ] && swapon --show | grep -q "/dev/zram0"; then
		log_ok "ZRAM enabled ($([ "$LOW_END_MODE" = true ] && echo "aggressive" || echo "balanced") mode)"
	else
		# Guard: check zram module presence before proceeding
		if ! lsmod | grep -q '^zram\b' && ! modinfo zram >/dev/null 2>&1; then
			log_warn "zram module not available for current kernel — skipping ZRAM setup"
		else
			log_warn "ZRAM generator did not activate; attempting manual setup"
			MEM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
			if [ "$LOW_END_MODE" = true ]; then
				ZMIB=$(awk -v m=$MEM_KB 'BEGIN{printf "%d", (m/1024)/1.33}')
			else
				ZMIB=$(awk -v m=$MEM_KB 'BEGIN{printf "%d", (m/1024)/2}')
			fi
			run_cmd "zramctl --find --size ${ZMIB}M --algorithm zstd || true"
			run_cmd "mkswap /dev/zram0 || true"
			run_cmd "swapon /dev/zram0 || true"
			if swapon --show | grep -q "/dev/zram0"; then
				log_ok "ZRAM manually activated (${ZMIB}M)"
			else
				log_warn "ZRAM activation failed; check journalctl -u systemd-zram-setup@zram0"
			fi
		fi
	fi
fi

# Journal size limit
mkdir -p /etc/systemd/journald.conf.d
backup_if_exists "/etc/systemd/journald.conf.d/99-size.conf"
write_file "/etc/systemd/journald.conf.d/99-size.conf" \
	"[Journal]
SystemMaxUse=100M
RuntimeMaxUse=$([ "$LOW_END_MODE" = true ] && echo "20M" || echo "30M")"

# Preload for faster app startup (guard availability)
run_cmd "systemctl list-unit-files | grep -q '^preload\\.service' && systemctl enable --now preload || true"
log_ok "Preload enable attempted (skipped if unavailable)"

# Gaming configuration
echo -e "${CYAN}${E_PROC} 7. GAMING OPTIMIZATION${RESET}"

# Gamemode config (universal)
backup_if_exists "/etc/gamemode.ini"
write_file "/etc/gamemode.ini" \
	"[general]
renice=10
iopriority=high
softrealtime=on
inhibit_screensaver=1
[custom]
start=__GL_SHADER_DISK_CACHE=1 MESA_SHADER_CACHE_DIR=~/.cache/mesa_shader_cache
end="
log_ok "Gamemode configured for maximum performance"

# Universal Shell Gaming Configuration Function (FIX: Comprehensive multi-shell)
configure_shell_gaming() {
	# Core gaming function/alias
	case "$SHELL_SYNTAX" in
	fish)
		if ! grep -q "function game" "$SHELL_CONFIG" 2>/dev/null; then
			run_su_user "mkdir -p ~/.config/fish"
			run_su_user "echo 'function game; game-performance gamemoderun mangohud \$argv; end' >> \"$SHELL_CONFIG\""
			log_ok "Fish gaming function added"
		fi
		;;
	zsh | bash)
		if ! grep -q "alias game=" "$SHELL_CONFIG" 2>/dev/null; then
			run_su_user "echo 'alias game=\"game-performance gamemoderun mangohud\"' >> \"$SHELL_CONFIG\""
			log_ok "$SHELL_SYNTAX gaming alias added"
		fi
		;;
	*)
		log_warn "Unsupported shell syntax: $SHELL_SYNTAX - skipping gaming alias"
		;;
	esac

	# Universal environment variables
	UNIVERSAL_VARS=(
		"__GL_SHADER_DISK_CACHE=1"
		"MESA_SHADER_CACHE_DIR=~/.cache/mesa_shader_cache"
		"ENABLE_FSR=1"
	)

	case "$SHELL_SYNTAX" in
	fish)
		for var in "${UNIVERSAL_VARS[@]}"; do
			key=$(echo $var | cut -d'=' -f1)
			value=$(echo $var | cut -d'=' -f2-)
			if ! grep -q "set -Ux $key" "$SHELL_CONFIG" 2>/dev/null; then
				run_su_user "echo \"set -Ux $key $value\" >> \"$SHELL_CONFIG\""
			fi
		done
		;;
	bash | zsh)
		for var in "${UNIVERSAL_VARS[@]}"; do
			if ! grep -q "export $var" "$SHELL_CONFIG" 2>/dev/null; then
				run_su_user "echo \"export $var\" >> \"$SHELL_CONFIG\""
			fi
		done
		;;
	esac
	log_ok "Universal gaming environment configured"
}

# GPU-specific Environment Configuration (FIX: Multi-shell GPU vars)
configure_gpu_env() {
	case "$GPU" in
	intel)
		if [ "$LOW_END_MODE" = true ]; then
			INTEL_VARS=(
				"MESA_GL_VERSION_OVERRIDE=3.3"
				"vblank_mode=0"
				"MESA_NO_DXT1=1"
				"LIBGL_DRI3_DISABLE=1"
			)
			case "$SHELL_SYNTAX" in
			fish)
				for var in "${INTEL_VARS[@]}"; do
					key=$(echo $var | cut -d'=' -f1)
					value=$(echo $var | cut -d'=' -f2-)
					if ! grep -q "set -Ux $key" "$SHELL_CONFIG" 2>/dev/null; then
						run_su_user "echo \"set -Ux $key $value\" >> \"$SHELL_CONFIG\""
					fi
				done
				;;
			bash | zsh)
				for var in "${INTEL_VARS[@]}"; do
					if ! grep -q "export $var" "$SHELL_CONFIG" 2>/dev/null; then
						run_su_user "echo \"export $var\" >> \"$SHELL_CONFIG\""
					fi
				done
				;;
			esac
			log_ok "Intel low-end optimizations applied ($SHELL_SYNTAX)"
		fi
		;;
	nvidia)
		NVIDIA_VARS=(
			"__GLX_VENDOR_LIBRARY_NAME=nvidia"
			"__NV_PRIME_RENDER_OFFLOAD=1"
		)
		case "$SHELL_SYNTAX" in
		fish)
			for var in "${NVIDIA_VARS[@]}"; do
				key=$(echo $var | cut -d'=' -f1)
				value=$(echo $var | cut -d'=' -f2-)
				if ! grep -q "set -Ux $key" "$SHELL_CONFIG" 2>/dev/null; then
					run_su_user "echo \"set -Ux $key $value\" >> \"$SHELL_CONFIG\""
				fi
			done
			;;
		bash | zsh)
			for var in "${NVIDIA_VARS[@]}"; do
				if ! grep -q "export $var" "$SHELL_CONFIG" 2>/dev/null; then
					run_su_user "echo \"export $var\" >> \"$SHELL_CONFIG\""
				fi
			done
			;;
		esac
		log_ok "NVIDIA environment optimized ($SHELL_SYNTAX)"
		;;
	amd)
		AMD_VARS=(
			"AMD_VULKAN_ICD=RADV"
			"VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json"
		)
		case "$SHELL_SYNTAX" in
		fish)
			for var in "${AMD_VARS[@]}"; do
				key=$(echo $var | cut -d'=' -f1)
				value=$(echo $var | cut -d'=' -f2-)
				if ! grep -q "set -Ux $key" "$SHELL_CONFIG" 2>/dev/null; then
					run_su_user "echo \"set -Ux $key $value\" >> \"$SHELL_CONFIG\""
				fi
			done
			;;
		bash | zsh)
			for var in "${AMD_VARS[@]}"; do
				if ! grep -q "export $var" "$SHELL_CONFIG" 2>/dev/null; then
					run_su_user "echo \"export $var\" >> \"$SHELL_CONFIG\""
				fi
			done
			;;
		esac
		log_ok "AMD Vulkan environment optimized ($SHELL_SYNTAX)"
		;;
	esac
}

# Execute gaming configurations
configure_shell_gaming
configure_gpu_env

log_ok "Ultimate gaming environment configured for $SHELL_SYNTAX"

# Desktop environment tweaks
echo -e "${CYAN}${E_PROC} 8. DESKTOP ENVIRONMENT TWEAKS${RESET}"

if [ "$PLASMA" = true ]; then
	log_ok "KDE Plasma detected — applying KDE-specific performance tweaks"
	# Ensure minimal Plasma components are present for tweaks to take effect
	if ! command -v plasmashell >/dev/null 2>&1 || ! command -v kwin_x11 >/dev/null 2>&1; then
		log_warn "Core Plasma components missing — installing minimal set"
		run_cmd "pacman -S --noconfirm --needed plasma-desktop plasma-workspace kde-cli-tools" || pacman_retry -S --noconfirm --needed plasma-desktop plasma-workspace kde-cli-tools
	fi
	# KWin (disable compositing for gaming)
	KWINRC="/etc/xdg/kwinrc"
	if [ ! -f "$KWINRC" ]; then touch "$KWINRC"; fi
	backup_if_exists "$KWINRC"
	if ! grep -q "MaxFPS" "$KWINRC" 2>/dev/null; then
		append_file "$KWINRC" "[Compositing]"
		append_file "$KWINRC" "MaxFPS=240"
		append_file "$KWINRC" "Enabled=false"
	fi

	# KDE Globals (ultra-light)
	KG="/etc/xdg/kdeglobals"
	backup_if_exists "$KG"
	if ! grep -q "UseRGBColor=true" "$KG" 2>/dev/null; then
		append_file "$KG" "[Colors:Window]"
		append_file "$KG" "UseRGBColor=true"
	fi
	if [ "$LOW_END_MODE" = true ]; then
		# Ensure kwriteconfig5 exists; if missing, install kde-cli-tools
		if ! command -v kwriteconfig5 >/dev/null 2>&1; then
			run_cmd "pacman -S --noconfirm --needed kde-cli-tools" || pacman_retry -S --noconfirm --needed kde-cli-tools || log_warn "Failed to install kde-cli-tools — continuing with file edit fallback"
		fi

		# Try per-user tweaks via su; if it fails, fallback to direct user file edits
		if su - "$USERNAME" -c true >/dev/null 2>&1; then
			KDE_WRITE_CMD="kwriteconfig5"
			if command_exists kwriteconfig6; then
				KDE_WRITE_CMD="kwriteconfig6"
			fi
			run_su_user "$KDE_WRITE_CMD --file kdeglobals --group KDE --key AnimationDuration 0"
			run_su_user "$KDE_WRITE_CMD --file kwinrc --group Compositing --key Enabled false"
		else
			# Fallback: edit user configuration files directly to avoid skipping
			UCFG_DIR="$USER_HOME/.config"
			U_KG="$UCFG_DIR/kdeglobals"
			U_KWIN="$UCFG_DIR/kwinrc"
			run_cmd "mkdir -p '$UCFG_DIR'"
			backup_if_exists "$U_KG"
			backup_if_exists "$U_KWIN"
			if ! grep -q "^\[KDE\]$" "$U_KG" 2>/dev/null; then
				append_file "$U_KG" "[KDE]"
			fi
			append_file "$U_KG" "AnimationDuration=0"
			if ! grep -q "^\[Compositing\]$" "$U_KWIN" 2>/dev/null; then
				append_file "$U_KWIN" "[Compositing]"
			fi
			append_file "$U_KWIN" "Enabled=false"
		fi
		log_ok "KDE ultra-light mode (no animations)"
	fi
	log_ok "KDE performance optimized"
else
	log_warn "Non-KDE desktop detected — skipping KDE-specific tweaks"
fi

# Storage optimization
echo -e "${CYAN}${E_PROC} 9. STORAGE PERFORMANCE${RESET}"

# Fstab noatime (root only)
ROOT_UUID=$(blkid -s UUID -o value "$(findmnt -n -o SOURCE /)" 2>/dev/null || echo "")
if [ -n "$ROOT_UUID" ] && grep -q "$ROOT_UUID" /etc/fstab && ! grep -q "noatime" /etc/fstab; then
	backup_if_exists "/etc/fstab"
	sed -i "/$ROOT_UUID/s/\(defaults,\)\?/\1noatime,/" /etc/fstab
	log_ok "Noatime added to root mount"
fi

# Storage scheduler (HDD vs SSD)
if [ "$STORAGE_TYPE" = "1" ]; then # HDD
	write_file "/etc/udev/rules.d/60-storage.rules" 'ACTION=="add", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="noop"'
	log_ok "HDD noop scheduler enabled"
else
	write_file "/etc/udev/rules.d/60-storage.rules" 'ACTION=="add", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"'
	log_ok "SSD/NVMe optimized"
fi

# Fstrim for SSD
if command -v fstrim >/dev/null 2>&1; then
	run_cmd "systemctl enable --now fstrim.timer"
	if [ "$DRYRUN" = false ]; then
		fstrim -av &>/dev/null || true
		log_ok "Fstrim enabled and run"
	fi
fi

# Service optimization (debloat)
echo -e "${CYAN}${E_PROC} 11. SERVICE OPTIMIZATION${RESET}"

# Disable bloatware (performance focus) only when --debloat is set
if [ "$DEBLOAT" = true ]; then
	BLOAT_SERVICES=(
		"ModemManager.service"
		"accounts-daemon.service"
		"packagekit.service"
		"geoclue.service"
		"tracker-miner-fs.service"
		"baloo.service"
	)

	for svc in "${BLOAT_SERVICES[@]}"; do
		if systemctl is-active --quiet "$svc" 2>/dev/null || systemctl is-enabled --quiet "$svc" 2>/dev/null; then
			run_cmd "systemctl disable --now ${svc}"
			log_ok "Disabled bloatware: $svc"
		fi
	done
	# FIX: Add || true to grep to prevent exit on no match
	enabled_services_count=$(systemctl list-unit-files --state=enabled | grep -cE "$(
		IFS='|'
		echo "${BLOAT_SERVICES[*]}"
	)" || true)
	optimized_count=$((${#BLOAT_SERVICES[@]} - enabled_services_count))
	log_ok "Debloat complete - ${optimized_count} services optimized"
else
	log_warn "Skipping debloat (enable with --debloat)"
fi

# Enable performance services (guard)
run_cmd "systemctl list-unit-files | grep -q '^gamemoded\\.service' && systemctl enable --now gamemoded.service || true"
log_ok "Gamemode daemon enable attempted (skipped if unavailable)"

# User & system cleanup
echo -e "${CYAN}${E_PROC} 12. USER & SYSTEM CLEANUP${RESET}"

# User cache cleanup (universal)
run_su_user "find ~/.cache -type f -name '*.db' -delete 2>/dev/null || true"
run_su_user "rm -rf ~/.local/share/Trash/* 2>/dev/null || true"
run_su_user "rm -rf ~/.cache/thumbnails/* 2>/dev/null || true"
log_ok "User cache cleaned"

# Pacman cache optimization
if command -v paccache >/dev/null 2>&1; then
	run_cmd "paccache -r -k2"
else
	run_cmd "pacman -Sc --noconfirm"
fi
log_ok "Pacman cache optimized"

# Weekly cleanup timer
CCS="/etc/systemd/system/cachyos-ultimate-clean.service"
CCT="/etc/systemd/system/cachyos-ultimate-clean.timer"
backup_if_exists "$CCS"
backup_if_exists "$CCT"

write_file "$CCS" "[Unit]
Description=CachyOS Ultimate Weekly Cleanup

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c \"/usr/bin/paccache -r -k2 >/dev/null 2>&1 || /usr/bin/pacman -Sc --noconfirm >/dev/null 2>&1; /bin/journalctl --vacuum-size=100M >/dev/null 2>&1; /usr/bin/fstrim -av >/dev/null 2>&1\""

write_file "$CCT" "[Unit]
Description=Weekly ultimate cleanup

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target"

run_cmd "systemctl daemon-reload"
run_cmd "systemctl enable --now cachyos-ultimate-clean.timer"
log_ok "Weekly cleanup timer installed"

# Journal vacuum
run_cmd "journalctl --vacuum-size=100M"
log_ok "Journal vacuum completed"

# Tmpfiles & final cleanup
echo -e "${CYAN}${E_PROC} 13. FINAL SYSTEM OPTIMIZATION${RESET}"

# Tmpfiles cleanup
TF="/etc/tmpfiles.d/cachyos-ultimate.conf"
backup_if_exists "$TF"
write_file "$TF" "# CachyOS Ultimate Cleanup
q /tmp 1777 root root $([ \"$LOW_END_MODE\" = true ] && echo \"7d\" || echo \"10d\") -
q /var/tmp 1777 root root $([ \"$LOW_END_MODE\" = true ] && echo \"7d\" || echo \"10d\") -"

run_cmd "systemctl restart systemd-tmpfiles-clean.timer"
log_ok "Tmpfiles cleanup configured"

# Final status
echo
echo -e "${CYAN}============================================================${RESET}"
if [ "$DRYRUN" = true ]; then
	log_ok "DRY-RUN COMPLETE — No changes applied"
	log_warn "Run again and choose 'n' to apply live changes"
else
	log_ok "SETUP COMPLETE"
	if [ -t 0 ]; then
		echo -ne "${CYAN}${E_ASK} Reboot now? (y/N): ${RESET}"
		read -r REBOOT_ANS || REBOOT_ANS="n"
		if echo "${REBOOT_ANS:-n}" | grep -qi '^y'; then
			run_cmd "reboot"
		else
			log_warn "Reboot later to apply all optimizations"
		fi
	else
		log_warn "Reboot required to apply all optimizations"
	fi
fi
log_ok "See README.md for usage and details"
echo -e "${CYAN}Log file: $LOG${RESET}"
exit 0
