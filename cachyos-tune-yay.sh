#!/bin/bash

# cachyos-tune.sh - ULTIMATE CachyOS Performance (BORE from AUR + Gaming Optimized)

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

	esac

done

# ===== Auto-setup minimal sudoers for yay =====
username=$(SUDO_USER=${SUDO_USER:-} logname 2>/dev/null || awk -F: '($3>=1000)&&($1!="nobody"){print $1; exit}')
if [ ! -f "/etc/sudoers.d/yay" ]; then
  echo "$username ALL=(ALL) NOPASSWD: /usr/bin/pacman, /usr/bin/makepkg" > /etc/sudoers.d/yay
  chmod 440 /etc/sudoers.d/yay
fi

# Root check (su - only)

if [ "$(id -u)" -ne 0 ]; then

	log_err "Error: run as real root su -"
	exit 1

fi

if [ -n "${SUDO_USER-}" ] || [ -n "${SUDO_COMMAND-}" ]; then

	log_err "Error: do NOT run via sudo. Use su -"
	exit 1

fi

# Detect user (FIXED: Better fresh install compatibility)

# Try logname first (works in most cases)
USERNAME=$(logname 2>/dev/null || echo "")

# Fallback 1: Check $SUDO_USER if run via sudo (shouldn't happen, but just in case)
if [ -z "$USERNAME" ] && [ -n "${SUDO_USER-}" ]; then
	USERNAME="$SUDO_USER"
fi

# Fallback 2: Find first non-root user with UID >= 1000
if [ -z "$USERNAME" ]; then
	USERNAME=$(awk -F: '$3>=1000 && $3<60000 && $1!="nobody" {print $1; exit}' /etc/passwd)
fi

# Fallback 3: Check who's logged in via who/w command
if [ -z "$USERNAME" ]; then
	USERNAME=$(who | awk '{print $1; exit}' 2>/dev/null || echo "")
fi

if [ -z "$USERNAME" ] || [ "$USERNAME" = "root" ]; then

	ERROR_DETAILS="Failed to detect non-root user.\n"
	ERROR_DETAILS+="Attempted methods:\n"
	ERROR_DETAILS+="  1. logname: $(logname 2>&1 || echo 'failed')\n"
	ERROR_DETAILS+="  2. \$SUDO_USER: ${SUDO_USER:-not set}\n"
	ERROR_DETAILS+="  3. /etc/passwd scan: $(awk -F: '$3>=1000 && $3<60000 && $1!="nobody" {print $1; exit}' /etc/passwd || echo 'no users found')\n"
	ERROR_DETAILS+="  4. who command: $(who | awk '{print $1; exit}' 2>&1 || echo 'failed')\n\n"
	ERROR_DETAILS+="Possible solutions:\n"
	ERROR_DETAILS+="  - Ensure you're logged in as a normal user\n"
	ERROR_DETAILS+="  - Then switch to root with: su -\n"
	ERROR_DETAILS+="  - Do NOT run this script directly as root\n"
	
	show_error_and_exit "Could not detect non-root user" 1 "$ERROR_DETAILS"

fi

USER_HOME=$(eval echo "~$USERNAME" 2>/dev/null || echo "")

# Fallback if eval fails
if [ -z "$USER_HOME" ] || [ "$USER_HOME" = "~$USERNAME" ]; then
	USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
fi

# Final validation
if [ ! -d "$USER_HOME" ]; then

	log_err "Error: user home not found: $USER_HOME"
	log_err "Trying to create Desktop directory in /home/$USERNAME"
	
	# Try alternative path
	if [ -d "/home/$USERNAME" ]; then
		USER_HOME="/home/$USERNAME"
		log_warn "Using /home/$USERNAME as user home"
	else
		ERROR_DETAILS="Home directory validation failed.\n"
		ERROR_DETAILS+="Expected: /home/$USERNAME\n"
		ERROR_DETAILS+="Found: $USER_HOME\n"
		ERROR_DETAILS+="Directory exists: $([ -d "$USER_HOME" ] && echo 'NO' || echo 'YES')\n\n"
		ERROR_DETAILS+="Attempted fallbacks:\n"
		ERROR_DETAILS+="  1. eval echo ~$USERNAME: $USER_HOME\n"
		ERROR_DETAILS+="  2. getent passwd: $(getent passwd "$USERNAME" | cut -d: -f6)\n"
		ERROR_DETAILS+="  3. /home/$USERNAME: $([ -d "/home/$USERNAME" ] && echo 'exists' || echo 'not found')\n\n"
		ERROR_DETAILS+="Possible solutions:\n"
		ERROR_DETAILS+="  - Create home directory: mkdir -p /home/$USERNAME\n"
		ERROR_DETAILS+="  - Fix ownership: chown $USERNAME:$USERNAME /home/$USERNAME\n"
		
		show_error_and_exit "Cannot find or create user home directory" 1 "$ERROR_DETAILS"
	fi

fi

# GLOBAL SHELL CONFIG PATHS (FIX: Define early to avoid undefined errors)

BASHRC="$USER_HOME/.bashrc"

ZSHRC="$USER_HOME/.zshrc"

FISHCFG="$USER_HOME/.config/fish/config.fish"

DEFAULT_CONFIG="$BASHRC"

# Setup logging (with directory creation safeguards)

LOG="$USER_HOME/Desktop/cachyos-ultimate-setup.log"

# Ensure Desktop directory exists
if [ ! -d "$USER_HOME/Desktop" ]; then
	if [ "$DRYRUN" = false ]; then
		mkdir -p "$USER_HOME/Desktop" 2>/dev/null || {
			# Fallback to /tmp if Desktop creation fails
			LOG="/tmp/cachyos-ultimate-setup-${USERNAME}.log"
			log_warn "Cannot create Desktop directory, using /tmp for log"
		}
	fi
fi

touch "$LOG" 2>/dev/null || true

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

# Helper function to show full error before exit
show_error_and_exit() {
	local error_msg="$1"
	local error_code="${2:-1}"
	local error_details="$3"
	
	log_err "$error_msg"
	
	if [ -n "$error_details" ]; then
		echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
		echo -e "${RED}FULL ERROR DETAILS:${RESET}"
		echo -e "$error_details"
		echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
	fi
	
	log_err "Script terminated with error code: $error_code"
	log_err "Check log file: $LOG"
	exit "$error_code"
}

# Helpers (MUST be defined before use)

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

# Shell detection function
detect_user_shell() {
	# Try getent first (most reliable)
	USER_SHELL=$(getent passwd "$USERNAME" 2>/dev/null | awk -F: '{print $7}' | xargs basename 2>/dev/null || echo "")
	
	# Fallback: check /etc/passwd directly
	if [ -z "$USER_SHELL" ]; then
		USER_SHELL=$(grep "^$USERNAME:" /etc/passwd 2>/dev/null | cut -d: -f7 | xargs basename 2>/dev/null || echo "")
	fi
	
	# Final fallback: assume bash
	if [ -z "$USER_SHELL" ]; then
		USER_SHELL="bash"
		log_warn "Could not detect shell, defaulting to bash"
	fi

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
	*bash | */sh | */dash | *)
		IS_FISH=false
		IS_BASH=true
		IS_ZSH=false
		SHELL_CONFIG="$DEFAULT_CONFIG"
		SHELL_SYNTAX="bash"
		if [[ "$USER_SHELL" != *"bash"* ]] && [[ "$USER_SHELL" != */sh ]] && [[ "$USER_SHELL" != */dash ]]; then
			log_warn "Unknown shell ($USER_SHELL), defaulting to bash"
		else
			log_ok "User shell detected: bash/sh"
		fi
		;;
	esac
	
	# Ensure shell config file exists
	if [ ! -f "$SHELL_CONFIG" ] && [ "$DRYRUN" = false ]; then
		touch "$SHELL_CONFIG" 2>/dev/null || log_warn "Could not create $SHELL_CONFIG"
		chown "$USERNAME":"$USERNAME" "$SHELL_CONFIG" 2>/dev/null || true
	fi
}

# Apply sysctl settings safely
apply_sysctl_safely() {
	log_ok "Applying supported sysctl settings for the current kernel..."
	# Read all .conf files, filter out comments/empty lines, and apply one-by-one.
	grep -rhvE '^\s*(#|$)' /etc/sysctl.d/ 2>/dev/null | while IFS= read -r line; do
		key=$(echo "$line" | cut -d'=' -f1 | tr -d '[:space:]')
		proc_path="/proc/sys/${key//./\/}"
		if [ -e "$proc_path" ]; then
			sysctl "$line" >/dev/null 2>&1 || true
		fi
	done
	log_ok "Live sysctl settings applied. Full configuration will be active on next boot."
	return 0
}

# Optional full system upgrade (before installs)

if [ "$FULL_UPGRADE" = true ]; then

	# Use -Syuu to allow downgrades (fixes "local package is newer" errors)
	run_cmd "pacman -Syuu --noconfirm"

	log_ok "System fully upgraded (with downgrade support)"

fi

# Pre-flight check: Ensure system is ready for fresh install
echo -e "${CYAN}${E_PROC} === PRE-FLIGHT CHECKS (Fresh Install Compatibility) ===${RESET}"

# Check 1: Pacman database accessibility
log_ok "Checking pacman database..."
if [ "$DRYRUN" = false ]; then
	rm -f /var/lib/pacman/db.lck 2>/dev/null || true
fi

if ! pacman -Q >/dev/null 2>&1; then
	log_warn "Pacman database initialization needed (common on fresh install)"
	
	if [ "$DRYRUN" = false ]; then
		log_ok "Initializing pacman database..."
		pacman-key --init 2>/dev/null || true
		pacman-key --populate archlinux cachyos 2>/dev/null || pacman-key --populate archlinux 2>/dev/null || true
		
		if pacman -Sy --noconfirm 2>/dev/null; then
			log_ok "Pacman database initialized"
		else
			ERROR_DETAILS="Pacman database initialization failed.\n"
			ERROR_DETAILS+="pacman-key --init: $(pacman-key --init 2>&1 | tail -3)\n"
			ERROR_DETAILS+="pacman-key --populate: $(pacman-key --populate archlinux 2>&1 | tail -3)\n"
			ERROR_DETAILS+="pacman -Sy: $(pacman -Sy --noconfirm 2>&1 | tail -5)\n\n"
			ERROR_DETAILS+="Possible solutions:\n"
			ERROR_DETAILS+="  1. Check internet: ping 8.8.8.8\n"
			ERROR_DETAILS+="  2. Remove lock: rm -f /var/lib/pacman/db.lck\n"
			ERROR_DETAILS+="  3. Manual init: pacman-key --init && pacman-key --populate\n"
			ERROR_DETAILS+="  4. Force sync: pacman -Syy\n"
			
			show_error_and_exit "Cannot initialize pacman" 1 "$ERROR_DETAILS"
		fi
	fi
else
	log_ok "Pacman database is accessible"
fi

# Check 2: Internet connectivity
log_ok "Checking internet connection..."
if ! ping -c1 -W3 8.8.8.8 >/dev/null 2>&1 && 
   ! ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; then
	log_warn "⚠️  No internet connection detected"
	log_warn "Script will run but package installations may fail"
	if [ -t 0 ]; then
		log_warn "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
		sleep 5
	fi
else
	log_ok "Internet connection verified ✓"
fi

# Check 3: Disk space
log_ok "Checking disk space..."
ROOT_SPACE=$(df / | awk 'NR==2 {print $4}' 2>/dev/null || echo "0")
if [ "$ROOT_SPACE" -gt 0 ]; then
	ROOT_SPACE_GB=$((ROOT_SPACE / 1024 / 1024))
	if [ "$ROOT_SPACE" -lt 5242880 ]; then  # Less than 5GB
		log_warn "Low disk space: ${ROOT_SPACE_GB}GB available on /"
		log_warn "Recommended: at least 5GB free for kernel installation"
	else
		log_ok "Disk space sufficient: ${ROOT_SPACE_GB}GB available"
	fi
fi

log_ok "Pre-flight checks completed ✓"
echo

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

# GPU detection (deferred)
GPU="generic"

# Detect shell
detect_user_shell

# Kernel: Install BORE kernel from AUR via YAY

echo -e "${CYAN}${E_PROC} 1. KERNEL OPTIMIZATION (BORE from AUR)${RESET}"

# SECTION 1a: Install YAY (AUR Helper) - MUST BE FIRST!
echo -e "${CYAN}${E_PROC} 1a. AUR Helper (YAY) Setup${RESET}"

# Install base-devel & git first
run_cmd "pacman -S --noconfirm --needed base-devel git go" || pacman_retry -S --noconfirm --needed base-devel git go

# Install yay (using PASSWORD-FREE method!)
if ! command -v yay &>/dev/null; then
	log_warn "Installing yay AUR helper (required for BORE kernel)..."
	AUR_DIR="$USER_HOME/.cache/aur/yay"
	
	if can_su_user && run_su_user "rm -rf '$AUR_DIR' && mkdir -p '$AUR_DIR' && git clone https://aur.archlinux.org/yay.git '$AUR_DIR'"; then
		# Build package without installing (no sudo needed for makepkg -s)
		log_ok "Building yay package..."
		if can_su_user && run_su_user "cd '$AUR_DIR' && makepkg -s --noconfirm"; then
			log_ok "yay package built successfully"
			
			# Find the built package with correct pattern matching
			PKG_FILE=$(find "$AUR_DIR" -maxdepth 1 -name 'yay-*.pkg.tar.*' -type f 2>/dev/null | head -1)
			
			if [ -n "$PKG_FILE" ] && [ -f "$PKG_FILE" ]; then
				log_ok "Installing yay package: $(basename "$PKG_FILE")"
				if run_cmd "pacman -U --noconfirm '$PKG_FILE'"; then
					log_ok "yay AUR helper installed successfully ✓"
					run_cmd "rm -rf '$AUR_DIR'" || true
				else
					log_warn "pacman -U failed, trying with retry..."
					if pacman_retry -U --noconfirm "$PKG_FILE"; then
						log_ok "yay installed via retry ✓"
						run_cmd "rm -rf '$AUR_DIR'" || true
					else
						ERROR_DETAILS="Failed to install yay package.\n\n"
						ERROR_DETAILS+="Package: $PKG_FILE\n\n"
						ERROR_DETAILS+="Last error:\n$(pacman -U --noconfirm '$PKG_FILE' 2>&1 | tail -10)\n\n"
						ERROR_DETAILS+="Manual installation:\n"
						ERROR_DETAILS+="  cd ~/.cache/aur/yay\n"
						ERROR_DETAILS+="  makepkg -si\n"
						show_error_and_exit "Cannot install yay" 1 "$ERROR_DETAILS"
					fi
				fi
			else
				log_err "Built package not found in $AUR_DIR"
				ERROR_DETAILS="yay package build succeeded but file not found.\n\n"
				ERROR_DETAILS+="Build directory: $AUR_DIR\n"
				ERROR_DETAILS+="Expected pattern: yay-*.pkg.tar.*\n"
				ERROR_DETAILS+="Directory contents:\n$(ls -la '$AUR_DIR' 2>&1)\n\n"
				ERROR_DETAILS+="Files found:\n$(find '$AUR_DIR' -name 'yay-*.pkg.tar.*' 2>&1)\n\n"
				ERROR_DETAILS+="Manual fix:\n"
				ERROR_DETAILS+="  sudo pacman -U $AUR_DIR/yay-*.pkg.tar.zst\n"
				show_error_and_exit "yay package not found" 1 "$ERROR_DETAILS"
			fi
			
		else
			log_err "makepkg build failed"
			run_cmd "rm -rf '$AUR_DIR'" || true
			ERROR_DETAILS="yay build failed.\n\n"
			ERROR_DETAILS+="Build log should be above.\n\n"
			ERROR_DETAILS+="Manual installation:\n"
			ERROR_DETAILS+="  git clone https://aur.archlinux.org/yay.git\n"
			ERROR_DETAILS+="  cd yay\n"
			ERROR_DETAILS+="  makepkg -si\n"
			show_error_and_exit "Cannot build yay" 1 "$ERROR_DETAILS"
		fi
	else
		log_err "Cannot clone yay repository or su to user"
		ERROR_DETAILS="Failed to setup yay build environment.\n\n"
		ERROR_DETAILS+="User: $USERNAME\n"
		ERROR_DETAILS+="Home: $USER_HOME\n"
		ERROR_DETAILS+="can_su_user: $(can_su_user && echo 'YES' || echo 'NO')\n\n"
		ERROR_DETAILS+="Manual installation:\n"
		ERROR_DETAILS+="  su - $USERNAME\n"
		ERROR_DETAILS+="  git clone https://aur.archlinux.org/yay.git\n"
		ERROR_DETAILS+="  cd yay && makepkg -si\n"
		show_error_and_exit "Cannot setup yay build environment" 1 "$ERROR_DETAILS"
	fi
else
	log_ok "yay already installed ✓"
fi

# SECTION 1b: Kernel Detection
echo -e "${CYAN}${E_PROC} 1b. Kernel Detection${RESET}"

# Get installed kernels
if ! pacman -Q &>/dev/null; then
	ERROR_DETAILS="Pacman database is corrupted or locked.\n\n"
	ERROR_DETAILS+="Database status:\n"
	ERROR_DETAILS+="$(pacman -Q 2>&1 | head -10)\n\n"
	ERROR_DETAILS+="Lock file: $([ -f /var/lib/pacman/db.lck ] && echo 'EXISTS (will be removed)' || echo 'not found')\n"
	
	run_cmd "rm -f /var/lib/pacman/db.lck"
	
	if ! pacman -Q &>/dev/null; then
		ERROR_DETAILS+="\nAutomatic fix failed.\n\n"
		ERROR_DETAILS+="Manual recovery:\n"
		ERROR_DETAILS+="  rm -f /var/lib/pacman/db.lck\n"
		ERROR_DETAILS+="  pacman -Syy\n"
		show_error_and_exit "Cannot access pacman database" 1 "$ERROR_DETAILS"
	fi
fi

INSTALLED_KERNELS=($(pacman -Q 2>/dev/null | grep '^linux-' | awk '{print $1}' || echo ""))

BORE_INSTALLED=false
KERNELS_TO_REMOVE=()

for kernel in "${INSTALLED_KERNELS[@]}"; do
	# Skip empty
	if [ -z "$kernel" ]; then
		continue
	fi

	# CRITICAL FIX: Only detect ACTUAL BORE kernel (with -bore suffix)
	# linux-cachyos-bore = BORE kernel (AUR) ✅
	# linux-cachyos = Standard CachyOS kernel (NOT BORE) ❌
	# linux-cachyos-lts = LTS kernel (NOT BORE) ❌
	if [[ "$kernel" == "linux-cachyos-bore" ]] || [[ "$kernel" == "linux-bore" ]]; then
		BORE_INSTALLED=true
		KERNEL_NAME="$kernel"
		log_ok "BORE kernel found: $kernel"
	else
		# Add all non-BORE kernels to removal list
		KERNELS_TO_REMOVE+=("$kernel")
		log_ok "Non-BORE kernel detected (will be removed): $kernel"
	fi
done

if [ "$BORE_INSTALLED" = false ]; then
	log_ok "No BORE kernel detected - fresh install detected"
	log_ok "Stock kernels found: ${KERNELS_TO_REMOVE[*]}"
else
	log_ok "BORE kernel already installed: $KERNEL_NAME"
fi

# SECTION 1c: Install BORE Kernel from AUR
echo -e "${CYAN}${E_PROC} 1c. BORE Kernel Installation (AUR)${RESET}"

if [ "$BORE_INSTALLED" = false ]; then
	log_ok "Installing BORE kernel from AUR via yay..."
	
	# Install BORE kernel + headers from AUR
	if su - "$username" -c "yay -S --noconfirm --needed linux-cachyos-bore linux-cachyos-bore-headers"; then
		log_ok "BORE kernel + headers installed from AUR ✓"
		KERNEL_NAME="linux-cachyos-bore"
	elif su - "$username" -c "yay -S --noconfirm --needed linux-cachyos-bore"; then
		log_ok "BORE kernel installed (trying headers separately...)"
		
		# Try to install headers separately
		if su - "$username" -c "yay -S --noconfirm --needed linux-cachyos-bore-headers"; then
			log_ok "BORE headers installed ✓"
		else
			log_warn "Headers install failed (non-critical)"
			log_warn "Install later: yay -S linux-cachyos-bore-headers"
		fi
		
		KERNEL_NAME="linux-cachyos-bore"
	else
		# Installation failed
		log_err "BORE kernel installation from AUR failed"
		ERROR_DETAILS="BORE kernel installation failed.\n\n"
		ERROR_DETAILS+="AUR package: linux-cachyos-bore\n\n"
		ERROR_DETAILS+="Last error:\n$(su - $USERNAME -c 'yay -S --noconfirm linux-cachyos-bore' 2>&1 | tail -10)\n\n"
		ERROR_DETAILS+="Manual installation:\n"
		ERROR_DETAILS+="  yay -S linux-cachyos-bore linux-cachyos-bore-headers\n\n"
		ERROR_DETAILS+="Alternative (if AUR is down):\n"
		ERROR_DETAILS+="  Use CachyOS repository: https://wiki.cachyos.org/\n"
		
		show_error_and_exit "Cannot install BORE kernel" 1 "$ERROR_DETAILS"
	fi
	
	# Generate initramfs
	if [ "$DRYRUN" = false ]; then
		if command -v mkinitcpio >/dev/null 2>&1; then
			mkinitcpio -P 2>/dev/null || log_warn "initramfs generation warning (non-fatal)"
		elif command -v dracut >/dev/null 2>&1; then
			dracut -f --regenerate-all 2>/dev/null || log_warn "initramfs generation warning (non-fatal)"
		fi
		log_ok "Initramfs generated"
	fi
	
	# Verify installation (check for BORE-specific kernel image)
	BORE_VMLINUZ=""
	if [ -f "/boot/vmlinuz-linux-cachyos-bore" ]; then
		BORE_VMLINUZ="/boot/vmlinuz-linux-cachyos-bore"
		KERNEL_NAME="linux-cachyos-bore"
		log_ok "BORE kernel installed successfully: linux-cachyos-bore ✓"
	elif [ -f "/boot/vmlinuz-linux-bore" ]; then
		BORE_VMLINUZ="/boot/vmlinuz-linux-bore"
		KERNEL_NAME="linux-bore"
		log_ok "BORE kernel installed successfully: linux-bore ✓"
	fi
	
	if [ -n "$BORE_VMLINUZ" ]; then
		log_ok "BORE kernel image found: $BORE_VMLINUZ"
	else
		log_warn "Kernel image not found, rebuilding initramfs..."
		run_cmd "mkinitcpio -P 2>/dev/null || dracut -f --regenerate-all 2>/dev/null || true"
		
		if [ ! -f "$BORE_VMLINUZ" ]; then
			ERROR_DETAILS="Kernel image not found after installation.\n\n"
			ERROR_DETAILS+="Expected: /boot/vmlinuz-linux-cachyos-bore OR /boot/vmlinuz-linux-cachyos\n"
			ERROR_DETAILS+="Boot directory:\n$(ls -la /boot/ 2>&1)\n\n"
			ERROR_DETAILS+="Installed kernel packages:\n$(pacman -Q | grep linux-cachyos)\n\n"
			ERROR_DETAILS+="Try manual initramfs rebuild:\n"
			ERROR_DETAILS+="  mkinitcpio -P\n"
			show_error_and_exit "Kernel image missing" 1 "$ERROR_DETAILS"
		fi
	fi
	
	# Verify headers are installed (check both naming conventions)
	HEADERS_INSTALLED=false
	if pacman -Qi "linux-cachyos-bore-headers" &>/dev/null; then
		HEADERS_INSTALLED=true
		log_ok "BORE kernel headers verified: linux-cachyos-bore-headers ✓"
	elif pacman -Qi "linux-cachyos-headers" &>/dev/null; then
		HEADERS_INSTALLED=true
		log_ok "BORE kernel headers verified: linux-cachyos-headers ✓"
	elif pacman -Qi "${KERNEL_NAME}-headers" &>/dev/null; then
		HEADERS_INSTALLED=true
		log_ok "BORE kernel headers verified: ${KERNEL_NAME}-headers ✓"
	fi
	
	if [ "$HEADERS_INSTALLED" = false ]; then
		log_warn "Headers not installed - installing now..."
		
		# Try to install headers with multiple naming attempts
		if su - "$username" -c "yay -S --noconfirm --needed linux-cachyos-bore-headers"; then
			log_ok "BORE headers installed via YAY ✓"
		elif run_cmd "pacman -S --noconfirm linux-cachyos-headers"; then
			log_ok "BORE headers installed via pacman ✓"
		else
			log_warn "Headers install failed - some features may not work"
			log_warn "Install manually: yay -S linux-cachyos-bore-headers"
			log_warn "Or try: pacman -S linux-cachyos-headers"
		fi
	fi
else
	log_ok "Using existing BORE kernel: $KERNEL_NAME ✓"
fi

# =================================================================
# SECTION 2: GRUB & Kernel Setup
# =================================================================

echo -e "${CYAN}${E_PROC} 2. GRUB & Kernel Setup${RESET}"

# Install GRUB tools if missing
if ! command -v grub-mkconfig &>/dev/null; then
	log_warn "Installing GRUB tools..."
	
	run_cmd "pacman -S --noconfirm --needed grub efibootmgr os-prober" || pacman_retry -S --noconfirm --needed grub efibootmgr os-prober || {
		ERROR_DETAILS="Failed to install GRUB tools.\n\n"
		ERROR_DETAILS+="Last pacman output:\n"
		ERROR_DETAILS+="$(pacman -S --noconfirm --needed grub efibootmgr os-prober 2>&1 | tail -10)\n\n"
		ERROR_DETAILS+="System information:\n"
		ERROR_DETAILS+="  - UEFI: $([ -d /sys/firmware/efi ] && echo 'YES' || echo 'NO (BIOS)')\n"
		ERROR_DETAILS+="  - Boot partition: $(df -h /boot 2>/dev/null || echo 'not mounted')\n"
		ERROR_DETAILS+="  - Internet: $(ping -c1 8.8.8.8 2>&1 | head -1)\n\n"
		ERROR_DETAILS+="Manual installation:\n"
		ERROR_DETAILS+="  sudo pacman -S grub efibootmgr os-prober\n"
		
		show_error_and_exit "Failed to install GRUB tools" 1 "$ERROR_DETAILS"
	}
	log_ok "GRUB tools installed"
else
	log_ok "GRUB tools available"
fi

# Enable OS-prober
log_ok "Enabling OS-prober..."
backup_if_exists "/etc/default/grub"

# Remove existing OS-prober settings
run_cmd "sed -i '/GRUB_DISABLE_OS_PROBER/d' /etc/default/grub"

# Enable OS-prober
run_cmd "echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub"

# No grub timeout
run_cmd "sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=-1/' /etc/default/grub"

# Grub timeout style
run_cmd "sed -i 's/^#GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub"

log_ok "OS-prober enabled"

# Update GRUB configuration
log_ok "Updating GRUB configuration..."
run_cmd "grub-mkconfig -o /boot/grub/grub.cfg"
log_ok "GRUB configuration updated"

# Set default kernel if grubby available

if command -v grubby &>/dev/null; then

	run_cmd "grubby --set-default /boot/vmlinuz-${KERNEL_NAME}"

	log_ok "BORE set as default kernel"

fi

# Simple preflight: verify BORE kernel is bootable before removing others
PRE_OK=true

if [ ! -f "/boot/vmlinuz-${KERNEL_NAME}" ]; then
	log_warn "BORE kernel image missing - cannot safely remove other kernels"
	PRE_OK=false
fi

if [ ! -f "/boot/initramfs-${KERNEL_NAME}.img" ] && [ ! -f "/boot/initramfs-${KERNEL_NAME}-fallback.img" ]; then
	log_warn "BORE initramfs missing - regenerating..."
	run_cmd "mkinitcpio -P 2>/dev/null || dracut -f --regenerate-all 2>/dev/null || true"
	
	if [ ! -f "/boot/initramfs-${KERNEL_NAME}.img" ] && [ ! -f "/boot/initramfs-${KERNEL_NAME}-fallback.img" ]; then
		log_warn "Initramfs still missing - cannot safely remove other kernels"
		PRE_OK=false
	fi
fi

if ! grep -q "${KERNEL_NAME}" /boot/grub/grub.cfg 2>/dev/null; then
	log_warn "BORE not in GRUB menu - regenerating..."
	run_cmd "grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true"
	
	if ! grep -q "${KERNEL_NAME}" /boot/grub/grub.cfg 2>/dev/null; then
		log_warn "GRUB entry missing - keeping other kernels as fallback"
		PRE_OK=false
	fi
fi

if [ "$PRE_OK" = true ]; then
	log_ok "BORE kernel verified - safe to remove other kernels"
else
	log_warn "Preflight checks failed - keeping other kernels for safety"
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

# Auto-detect kernel and apply appropriate scheduler optimizations
backup_if_exists "/etc/sysctl.d/97-gaming-kernel.conf"

if [[ "$KERNEL_NAME" == *"bore"* ]]; then
	# BORE-specific optimizations
	write_file "/etc/sysctl.d/97-gaming-kernel.conf" \
		"# BORE Kernel Gaming Optimizations" \
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
	
	if [ "$LOW_END_MODE" = true ]; then
		append_file "/etc/sysctl.d/97-gaming-kernel.conf" "# Low-end hardware"
		append_file "/etc/sysctl.d/97-gaming-kernel.conf" "kernel.sched_latency_ns=6000000"
		append_file "/etc/sysctl.d/97-gaming-kernel.conf" "kernel.sched_min_granularity_ns=1500000"
		log_ok "BORE low-end optimizations applied"
	fi
	
	log_ok "BORE kernel optimizations configured"
else
	# Zen/Standard kernel optimizations (universal settings only)
	write_file "/etc/sysctl.d/97-gaming-kernel.conf" \
		"# Zen/Performance Kernel Gaming Optimizations" \
		"kernel.sched_autogroup_enabled=1" \
		"kernel.sched_child_runs_first=1" \
		"kernel.sched_latency_ns=8000000" \
		"kernel.sched_migration_cost_ns=5000000" \
		"kernel.sched_min_granularity_ns=3000000" \
		"kernel.sched_wakeup_granularity_ns=2000000" \
		"kernel.sched_tunable_scaling=1"
	
	log_ok "Standard kernel optimizations configured"
fi

if [ "$DRYRUN" = false ]; then
	apply_sysctl_safely
	log_ok "Performance scheduler loaded - maximum responsiveness"
fi

# =================================================================
# SECTION 3: CORE PACKAGES & GPU OPTIMIZATION
# =================================================================

echo -e "${CYAN}${E_PROC} 3. CORE PACKAGES & GPU OPTIMIZATION${RESET}"

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

# GPU detection (now that pciutils is installed)
log_ok "Detecting GPU hardware..."

if ! command -v lspci &>/dev/null; then
	run_cmd "pacman -S --noconfirm --needed pciutils" || pacman_retry -S --noconfirm --needed pciutils
fi

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
		log_warn "Generic GPU - using Mesa"
	fi
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

# CachyOS gaming package

#run_cmd "pacman -S --noconfirm cachyos-gaming-meta || true" || pacman_retry -S --noconfirm cachyos-gaming-meta || true
run_cmd "pacman -S --noconfirm lutris || true" || pacman_retry -S --noconfirm lutris || true
run_cmd "pacman -S --noconfirm heroic-games-launcher || true" || pacman_retry -S --noconfirm heroic-games-launcher || true

log_ok "Gaming packages installed"

# =================================================================
# SECTION 4: POWER MANAGEMENT (TLP PERFORMANCE)
# =================================================================

echo -e "${CYAN}${E_PROC} 4. POWER MANAGEMENT (TLP PERFORMANCE)${RESET}"

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

# =================================================================
# SECTION 5: ULTIMATE SYSCTL PERFORMANCE
# =================================================================

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

# =================================================================
# SECTION 6: MEMORY & STORAGE OPTIMIZATION
# =================================================================

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

# =================================================================
# SECTION 7: GAMING OPTIMIZATION
# =================================================================

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

# =================================================================
# SECTION 8: DESKTOP ENVIRONMENT TWEAKS
# =================================================================

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

# =================================================================
# SECTION 9: STORAGE PERFORMANCE
# =================================================================

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

# =================================================================
# SECTION 10: SERVICE OPTIMIZATION
# =================================================================

echo -e "${CYAN}${E_PROC} 10. SERVICE OPTIMIZATION${RESET}"

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
	# enabled_services_count check
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

# =================================================================
# SECTION 11: USER & SYSTEM CLEANUP
# =================================================================

echo -e "${CYAN}${E_PROC} 11. USER & SYSTEM CLEANUP${RESET}"

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

# =================================================================
# SECTION 12: FINAL SYSTEM OPTIMIZATION
# =================================================================

echo -e "${CYAN}${E_PROC} 12. FINAL SYSTEM OPTIMIZATION${RESET}"

# Tmpfiles cleanup
TF="/etc/tmpfiles.d/cachyos-ultimate.conf"
backup_if_exists "$TF"
write_file "$TF" "# CachyOS Ultimate Cleanup
q /tmp 1777 root root $([ \"$LOW_END_MODE\" = true ] && echo \"7d\" || echo \"10d\") -
q /var/tmp 1777 root root $([ \"$LOW_END_MODE\" = true ] && echo \"7d\" || echo \"10d\") -"

run_cmd "systemctl restart systemd-tmpfiles-clean.timer"
log_ok "Tmpfiles cleanup configured"

# =================================================================
# FINAL STATUS
# =================================================================

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
			log_ok "Rebooting system..."
			if [ "$DRYRUN" = false ]; then
				reboot
				# Script will exit via reboot, but add exit for safety
				exit 0
			else
				log_warn "[DRY-RUN] Would reboot system"
			fi
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
