# arch-easyprint

Arch EasyPrint is a script that makes printer and scanner detection on Arch Linux as simple as it is on Windows, macOS, and Ubuntu. Linux has historically made it difficult to get printers and scanners working out of the box. This project aims to fix that. Skip the hours spent on the wiki and get your devices up and running effortlessly.

## What it does

- Installs all required packages for printing and scanning (CUPS, Gutenprint, IPP-USB, SANE AirScan, Avahi, and more)
- Detects your desktop environment and installs the appropriate GUI tools (GNOME or KDE)
- Enables CUPS with socket-based activation (starts on demand, no boot slowdown)
- Enables Avahi and IPP-USB for automatic network and USB device discovery
- Configures `/etc/nsswitch.conf` for mDNS-based network printer and scanner discovery
- Detects and configures your firewall (UFW, firewalld, or iptables) to open the required ports
- Warns if `systemd-resolved` mDNS conflicts with Avahi

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
git clone https://github.com/yourusername/arch-easyprint.git
cd arch-easyprint
chmod +x easyprint.sh
./easyprint.sh
```

After the script finishes, add your printer through the CUPS web interface at `http://localhost:631/` or through your desktop environment's printer settings.

## Notes

- Do **not** enable `cups-browsed.service`. It is not needed for DNS-SD/mDNS printer discovery and will significantly slow down boot time.
- If your printer or scanner is not detected after running the script, try logging out and back in or restarting your computer.
- If you use `systemd-resolved` with mDNS enabled, it may conflict with Avahi. Disable it by setting `MulticastDNS=no` in `/etc/systemd/resolved.conf`.

## License

See [LICENSE](LICENSE).
