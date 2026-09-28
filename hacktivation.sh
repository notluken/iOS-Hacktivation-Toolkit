#!/bin/bash
#
# iOS Hacktivation Toolkit
#
# Originally by exploit-development (https://github.com/exploit-development/iOS-Hacktivation-Toolkit)
# Updated by KŌGA (https://github.com/notluken) — iOS 15 support, macOS compatibility, palera1n integration
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

REQUIRED_TOOLS=(ideviceinfo idevicerestore irecovery palera1n sshpass iproxy)

###############################################################################
# Generic helpers
###############################################################################

# Case-insensitive yes check (replaces the old Y/y/Yes/yes/YES ladder).
is_yes() {
  case "$1" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

wait_for_enter() {
  echo ""
  read -rp "Press Enter to return to the menu... " _
}

# Prints an install hint for a missing tool, based on the host OS.
tool_hint() {
  local tool="$1"
  if [ "$(uname -s)" = "Darwin" ]; then
    case "$tool" in
      ideviceinfo) echo "brew install libimobiledevice" ;;
      idevicerestore) echo "brew tap stek29/homebrew-idevice && brew install idevicerestore (or: sudo port install idevicerestore)" ;;
      irecovery) echo "brew install libirecovery" ;;
      iproxy) echo "brew install libusbmuxd" ;;
      sshpass) echo "brew install hudochenkov/sshpass/sshpass" ;;
      palera1n) echo "curl -fsSL https://static.palera.in/scripts/install.sh | sh (see https://docs.palera.in)" ;;
      *) echo "see https://docs.palera.in or your package manager" ;;
    esac
  else
    case "$tool" in
      ideviceinfo) echo "sudo apt install libimobiledevice-utils" ;;
      idevicerestore) echo "sudo apt install idevicerestore" ;;
      irecovery) echo "sudo apt install irecovery" ;;
      iproxy) echo "sudo apt install usbmuxd" ;;
      sshpass) echo "sudo apt install sshpass" ;;
      palera1n) echo "curl -fsSL https://static.palera.in/scripts/install.sh | sh (see https://docs.palera.in)" ;;
      *) echo "check your distribution's package manager" ;;
    esac
  fi
}

# Verbose check used by menu option 1: prints a status line per tool.
check_dependencies() {
  echo ""
  echo -e "${YELLOW}Checking required tools...${NC}"
  echo ""

  local tool missing=()
  for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      echo -e "  ${GREEN}[ ok ]${NC} $tool"
    else
      echo -e "  ${RED}[miss]${NC} $tool"
      missing+=("$tool")
    fi
  done
  echo ""

  if [ ${#missing[@]} -eq 0 ]; then
    echo -e "${GREEN}All required tools are installed.${NC}"
    return 0
  fi

  echo -e "${YELLOW}Install the missing tools:${NC}"
  for tool in "${missing[@]}"; do
    echo -e "  ${YELLOW}${tool}${NC} -> $(tool_hint "$tool")"
  done
  return 1
}

# Silent gate used before running a feature: prints only if something is missing.
require_tools() {
  local tool missing=()
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done

  if [ ${#missing[@]} -eq 0 ]; then
    return 0
  fi

  echo ""
  echo -e "${RED}Missing required tool(s): ${missing[*]}${NC}"
  for tool in "${missing[@]}"; do
    echo -e "  ${YELLOW}${tool}${NC} -> $(tool_hint "$tool")"
  done
  return 1
}

###############################################################################
# Device info / banner
###############################################################################

print_banner() {
  echo -e "${GREEN}"
  echo " **********************************************************************"
  echo " ********************** iOS Hacktivation Toolkit **********************"
  echo -e " **********************************************************************${NC}"
}

# Extracts the value of a "Key: Value" line from cached ideviceinfo output.
device_field() {
  printf '%s\n' "$1" | grep -m1 "^$2: " | cut -d' ' -f2-
}

print_device_info() {
  echo ""

  if ! command -v ideviceinfo >/dev/null 2>&1; then
    echo -e "${YELLOW}ideviceinfo not found — run option 1 to check dependencies.${NC}"
    return
  fi

  local info_output
  info_output="$(ideviceinfo 2>/dev/null)"

  if [ -z "$info_output" ]; then
    echo ' ----------------------------------------------------------------------'
    echo -e "${RED}                     CANNOT CONNECT TO DEVICE${NC}"
    echo ' ----------------------------------------------------------------------'
    return
  fi

  local device_name product_type product_version serial activation_state activation_color
  device_name="$(device_field "$info_output" "DeviceName")"
  product_type="$(device_field "$info_output" "ProductType")"
  product_version="$(device_field "$info_output" "ProductVersion")"
  serial="$(device_field "$info_output" "SerialNumber")"
  activation_state="$(device_field "$info_output" "ActivationState")"

  if [ "$activation_state" = "Activated" ]; then
    activation_color="$GREEN"
  else
    activation_color="$RED"
  fi

  echo ' ----------------------------------------------------------------------'
  echo -e "${GREEN} Device: ${NC}${device_name}   ${GREEN}Model: ${NC}${product_type}   ${GREEN}iOS: ${NC}${product_version}"
  echo -e "${GREEN} Serial: ${NC}${serial}   ${GREEN}Activation: ${NC}${activation_color}${activation_state}${NC}"
  echo ' ----------------------------------------------------------------------'
}

###############################################################################
# Menu actions
###############################################################################

restore_device() {
  if ! require_tools idevicerestore; then
    return
  fi

  echo ""
  echo -e "${YELLOW}This performs a full restore and ERASES all data on the device.${NC}"
  read -rp "Continue? [y/N] " confirm

  if is_yes "$confirm"; then
    idevicerestore -e -l
  else
    echo -e "${CYAN}Cancelled.${NC}"
  fi
}

jailbreak_device() {
  if ! require_tools palera1n; then
    return
  fi
  palera1n
}

activation_bypass_menu() {
  while true; do
    clear
    print_banner
    print_device_info
    echo ""
    echo -e "${YELLOW}Activation Bypass — choose the iOS version installed on the device:${NC}"
    echo ' ----------------------------------------------------------------------'
    echo -e "${CYAN} 1 : iOS 12.x${NC}"
    echo -e "${CYAN} 2 : iOS 13.x${NC}"
    echo -e "${CYAN} 3 : iOS 14.x - 15.x (ldid re-signing)${NC}"
    echo -e "${CYAN} 0 : Back${NC}"
    echo ' ----------------------------------------------------------------------'
    if ! read -rp " Choose > " sub_choice; then
      echo ""
      echo -e "${RED}No input received. Exiting...${NC}"
      exit 1
    fi

    case "$sub_choice" in
      1) run_bypass "mobileactivationd_12_4_7"; return ;;
      2) run_bypass "mobileactivationd_13_x"; return ;;
      3) run_bypass "mobileactivationd_15_x"; return ;;
      0) return ;;
      *)
        echo -e "${YELLOW}Option not found.${NC}"
        wait_for_enter
        ;;
    esac
  done
}

run_bypass() {
  local dir="$1"
  local script="$SCRIPT_DIR/bypass_scripts/$dir/run.sh"

  if [ ! -f "$script" ]; then
    echo -e "${RED}Bypass script not found: $script${NC}"
    wait_for_enter
    return
  fi

  if ! require_tools sshpass iproxy ideviceinfo; then
    wait_for_enter
    return
  fi

  bash "$script"
  wait_for_enter
}

ssh_shell() {
  if ! require_tools sshpass iproxy; then
    wait_for_enter
    return
  fi

  echo ""
  echo -e "${CYAN}Opening an SSH shell over USB (local port 2222 -> device port 44)...${NC}"

  rm -f ~/.ssh/known_hosts >/dev/null 2>&1
  pkill -f 'iproxy 2222:44' >/dev/null 2>&1

  iproxy 2222:44 >/dev/null 2>&1 &
  local iproxy_pid=$!
  sleep 2

  sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 root@localhost mount -o rw,union,update /
  sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 root@localhost

  kill "$iproxy_pid" >/dev/null 2>&1
  wait_for_enter
}

###############################################################################
# Main menu
###############################################################################

main_menu() {
  clear
  print_banner
  print_device_info

  echo ""
  echo -e "${YELLOW} Select an option:${NC}"
  echo ' ----------------------------------------------------------------------'
  echo -e "${CYAN} 1 : Check Dependencies${NC}"
  echo -e "${CYAN} 2 : Restore Device (idevicerestore)${NC}"
  echo -e "${CYAN} 3 : Jailbreak (palera1n)${NC}"
  echo -e "${CYAN} 4 : Activation Bypass${NC}"
  echo -e "${CYAN} 5 : SSH Shell${NC}"
  echo -e "${CYAN} 0 : Exit${NC}"
  echo ' ----------------------------------------------------------------------'
  if ! read -rp " Choose > " choice; then
    echo ""
    echo -e "${RED}No input received. Exiting...${NC}"
    exit 1
  fi

  case "$choice" in
    1)
      check_dependencies
      wait_for_enter
      ;;
    2)
      restore_device
      wait_for_enter
      ;;
    3)
      jailbreak_device
      wait_for_enter
      ;;
    4)
      activation_bypass_menu
      ;;
    5)
      ssh_shell
      ;;
    0)
      echo -e "${RED}Exiting...${NC}"
      exit 0
      ;;
    *)
      echo -e "${YELLOW}Option not found.${NC}"
      wait_for_enter
      ;;
  esac
}

while true; do
  main_menu
done
