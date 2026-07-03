# Arch EasyPrint

Arch EasyPrint is a setup script that makes printer and scanner detection on Arch Linux easier to configure. It installs the common printing and scanning packages, enables discovery services, updates `nsswitch.conf` for mDNS, and applies basic firewall rules when UFW or firewalld is active.

The goal is to reduce the amount of manual setup needed to get printers and scanners working on a fresh Arch-based desktop.

## What it does

- Installs required packages for printing and scanning, including CUPS, Gutenprint, IPP-USB, SANE AirScan, Avahi, and nss-mdns
- Runs a normal `pacman -Syu --needed` transaction instead of only refreshing package databases
- Detects GNOME or KDE Plasma and installs the appropriate GUI tools
- Enables `cups.socket` for socket-based CUPS activation
- Enables Avahi and IPP-USB for automatic network and USB device discovery
- Creates a timestamped backup of `/etc/nsswitch.conf` before changing it
- Adds mDNS hostname resolution to the existing `hosts:` line without replacing the whole line unnecessarily
- Warns if `systemd-resolved` mDNS appears to be enabled
- Detects UFW or firewalld and opens the required discovery/scanning ports

## Packages installed

| Package | Purpose |
|---|---|
| `cups` | Core printing system |
| `cups-pdf` | Virtual PDF printer |
| `ipp-usb` | Driverless USB printing and scanning via IPP |
| `gutenprint` | Printer drivers |
| `ghostscript` | PostScript and PDF rendering |
| `gsfonts` | Fonts for Ghostscript |
| `foomatic-db-gutenprint-ppds` | Gutenprint PPD files |
| `foomatic-db-engine` | Foomatic filter engine |
| `foomatic-db` | Open-source printer driver database |
| `foomatic-db-nonfree` | Non-free printer driver database |
| `avahi` | mDNS/DNS-SD for network device discovery |
| `nss-mdns` | NSS module for mDNS hostname resolution |
| `sane-airscan` | Driverless network and USB scanner support |

## Usage

```bash
git clone https://github.com/davgar99/arch-easyprint.git
cd arch-easyprint
chmod +x easyprint.sh
./easyprint.sh
```

The script can be run from inside the repository. It locates `packages.txt` relative to the script path, so it does not depend on your current working directory once the repository has been cloned.

After the script finishes, add your printer through the CUPS web interface at `http://localhost:631/` or through your desktop environment's printer manager.

## Notes

- Do **not** enable `cups-browsed.service`. It is not needed for DNS-SD/mDNS printer discovery and can significantly slow down boot time.
- The script creates a timestamped backup of `/etc/nsswitch.conf` before editing it.
- If your printer or scanner is not detected after running the script, try logging out and back in or restarting your computer.
- If you use `systemd-resolved` with mDNS enabled, it may conflict with Avahi. Disable it by setting `MulticastDNS=no` in `/etc/systemd/resolved.conf`.

## License

See [LICENSE](LICENSE).
