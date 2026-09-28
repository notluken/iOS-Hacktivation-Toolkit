# iOS Hacktivation Toolkit

**Activation Lock Bypass for checkm8-compatible iOS devices**

Originally created by [exploit-development](https://github.com/exploit-development/iOS-Hacktivation-Toolkit). Updated and maintained by [KŌGA](https://github.com/notluken).

## Supported iOS versions

- iOS 12.x
- iOS 13.x
- iOS 14.x
- iOS 15.x

## Supported devices

All checkm8-compatible devices (A5 through A11 chips).

## Requirements

The toolkit runs on both macOS and Linux. It shells out to the following tools, which must be available on `PATH`:

| Tool             | Purpose                                | macOS (Homebrew)                                                              | Linux (apt)                          |
|------------------|-----------------------------------------|---------------------------------------------------------------------------------|----------------------------------------|
| `ideviceinfo`    | Read device info                        | `brew install libimobiledevice`                                                 | `sudo apt install libimobiledevice-utils` |
| `idevicerestore` | Restore/reflash firmware                 | `brew tap stek29/homebrew-idevice && brew install idevicerestore` (or MacPorts: `sudo port install idevicerestore`) | `sudo apt install idevicerestore`     |
| `irecovery`      | Talk to the device in recovery/DFU mode  | `brew install libirecovery`                                                     | `sudo apt install irecovery`          |
| `palera1n`       | Jailbreak (checkm8-based)                 | see [docs.palera.in](https://docs.palera.in)                                    | see [docs.palera.in](https://docs.palera.in) |
| `sshpass`        | Non-interactive SSH over USB             | `brew install hudochenkov/sshpass/sshpass`                                      | `sudo apt install sshpass`            |
| `iproxy`         | USB port forwarding for SSH               | `brew install libusbmuxd`                                                       | `sudo apt install usbmuxd`             |

Run `./hacktivation.sh` and pick **1. Check Dependencies** at any time to see exactly what is missing on your system.

## Quick start

```bash
git clone https://github.com/notluken/iOS-Hacktivation-Toolkit.git
cd iOS-Hacktivation-Toolkit
chmod +x hacktivation.sh
./hacktivation.sh
```

1. Connect the device and pick **1. Check Dependencies** to confirm your setup is complete.
2. If the device needs a firmware restore, use **2. Restore Device (idevicerestore)**. This erases the device.
3. Jailbreak the device with **3. Jailbreak (palera1n)**.
4. Once the device has booted jailbroken, use **4. Activation Bypass** and pick the iOS version installed on the device (12.x, 13.x, or 14.x-15.x).
5. Use **5. SSH Shell** any time you need a raw shell on the device over USB.

## How it works

`mobileactivationd` is the system daemon that Setup Assistant and SpringBoard query to check whether a device is activated. On a jailbroken device, this toolkit replaces `/usr/libexec/mobileactivationd` with a patched binary that always reports the device as activated, restarts the daemon (`launchctl unload` / `launchctl load`), and respawns SpringBoard (`uicache` + `killall SpringBoard`) so the change takes effect immediately.

On iOS 14.x and 15.x, a plain binary swap is not enough: the system rejects the replacement unless it carries the same entitlements as the original binary. The iOS 14.x-15.x bypass script handles this by dumping the original binary's entitlements with `ldid -e`, backing up the original, installing the patched binary, and re-signing it in place with `ldid -S` before restarting the daemon.

## Notes

- **Semi-tethered**: checkra1n/palera1n jailbreaks are semi-tethered. A reboot (or a battery drain) reverts the device to its unpatched state, so the device must be put back into DFU mode, re-jailbroken, and re-patched after every reboot.
- **Default SSH password**: the toolkit connects to the device over USB using the jailbreak community's default `root` password, `alpine`.

## Disclaimer

This tool is for educational and research purposes. Only use it on devices you own.

## License

GNU General Public License v3.0. See the license header in each script, or <https://www.gnu.org/licenses/gpl-3.0.html>.
