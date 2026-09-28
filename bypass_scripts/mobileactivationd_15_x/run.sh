#!/bin/bash
#
# Activation Lock bypass for iOS 14.x - 15.x.
#
# Reuses the iOS 13.x patched mobileactivationd binary (see the "mobileactivationd"
# symlink in this directory, which points at bypass_scripts/mobileactivationd_13_x/).
# Unlike iOS 13, iOS 14+ enforces entitlement checks that reject a plain binary
# swap, so this script also re-signs the patched binary with the original
# binary's entitlements via ldid.
#
# The device must already be jailbroken and booted (palera1n), with its SSH
# server reachable on port 44.

set -u

GREEN='\033[1;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_PASS="alpine"
LOCAL_PORT=2222
DEVICE_PORT=44
LAUNCH_PLIST="/System/Library/LaunchDaemons/com.apple.mobileactivationd.plist"
REMOTE_BIN="/usr/libexec/mobileactivationd"
REMOTE_ENTITLEMENTS="/tmp/ents.xml"

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

  ssh_cmd mount -o rw,union,update /
  ssh_cmd "ldid -e $REMOTE_BIN > $REMOTE_ENTITLEMENTS"
  ssh_cmd cp "$REMOTE_BIN" "$REMOTE_BIN.bak"
  scp_cmd "$SCRIPT_DIR/mobileactivationd" "root@localhost:$REMOTE_BIN"
  ssh_cmd chmod 755 "$REMOTE_BIN"
  ssh_cmd "ldid -S$REMOTE_ENTITLEMENTS $REMOTE_BIN"
  ssh_cmd launchctl unload "$LAUNCH_PLIST"
  ssh_cmd launchctl load "$LAUNCH_PLIST"
  ssh_cmd uicache -a
  ssh_cmd killall SpringBoard

  echo -e "${GREEN}Activation bypass applied for iOS 14.x - 15.x.${NC}"
}

main
