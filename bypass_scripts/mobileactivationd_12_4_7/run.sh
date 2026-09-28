#!/bin/bash
#
# Activation Lock bypass for iOS 12.4.7.
#
# Replaces the stock /usr/libexec/mobileactivationd with a patched binary
# over an SSH-over-USB tunnel. The device must already be jailbroken and
# booted (checkra1n/palera1n), with its SSH server reachable on port 44.

set -u

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_PASS="alpine"
LOCAL_PORT=2222
DEVICE_PORT=44
LAUNCH_PLIST="/System/Library/LaunchDaemons/com.apple.mobileactivationd.plist"

ssh_cmd() {
  sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$LOCAL_PORT" root@localhost "$@"
}

scp_cmd() {
  sshpass -p "$SSH_PASS" scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P "$LOCAL_PORT" "$@"
}

cleanup() {
  pkill -f "iproxy $LOCAL_PORT:$DEVICE_PORT" >/dev/null 2>&1
}
trap cleanup EXIT

wait_for_device() {
  echo -e "${CYAN}Waiting for the device over USB. If nothing happens, disconnect and reconnect the USB cable.${NC}"
  while true; do
    local result
    result=$(ssh -p "$LOCAL_PORT" -o BatchMode=yes -o ConnectTimeout=1 root@localhost echo ok 2>&1 | grep Connection)
    if [ -z "$result" ]; then
      echo -e "${GREEN}Connected to device.${NC}"
      return
    fi
    sleep 1
  done
}

main() {
  rm -f ~/.ssh/known_hosts >/dev/null 2>&1
  cleanup

  iproxy "$LOCAL_PORT:$DEVICE_PORT" >/dev/null 2>&1 &
  sleep 1

  wait_for_device

  echo -e "${YELLOW}Continue to the \"Choose a Wi-Fi Network\" screen but do not connect to a network.${NC}"
  read -rp "Press Enter to continue... " _

  ssh_cmd mount -o rw,union,update /
  ssh_cmd launchctl unload "$LAUNCH_PLIST"
  ssh_cmd rm -f /usr/libexec/mobileactivationd
  ssh_cmd uicache --all
  scp_cmd "$SCRIPT_DIR/mobileactivationd" "root@localhost:/usr/libexec/mobileactivationd"
  ssh_cmd chmod 755 /usr/libexec/mobileactivationd
  ssh_cmd launchctl load "$LAUNCH_PLIST"

  echo -e "${GREEN}Activation bypass applied for iOS 12.4.7.${NC}"
  echo -e "${CYAN}On the device, choose \"Connect to iTunes\" to complete the bypass.${NC}"
}

main
