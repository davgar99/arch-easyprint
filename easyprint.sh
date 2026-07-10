#!/usr/bin/env bash
set -euo pipefail

# Define color variables
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
ENDCOLOR=$'\033[0m'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_FILE="$SCRIPT_DIR/packages.txt"
ORIGINAL_FILE="/etc/nsswitch.conf"

if ! command -v sudo >/dev/null 2>&1; then
    printf '%s\n' "${RED}ERROR: sudo is required to run this script.${ENDCOLOR}"
    exit 1
fi

cat << EOF
Welcome to Arch-EasyPrint!
This script will install the required packages and dependencies to have your printer and scanner up and running.
EOF

while true; do
    read -r -p "Do you want to continue? (Y/n): " response
    case "$response" in
        [Yy])
            printf '%s\n' "${YELLOW}You responded with Y. Continuing.${ENDCOLOR}"
            break
            ;;
        [Nn])
            printf '%s\n' "${YELLOW}You responded with N. Exiting.${ENDCOLOR}"
            exit 0
            ;;
        *)
            printf '%s\n' "${YELLOW}Invalid response. Please enter Y or N.${ENDCOLOR}"
            ;;
    esac
done

if ! command -v pacman >/dev/null 2>&1; then
    printf '%s\n' "${RED}ERROR: pacman was not found. This script is intended for Arch-based systems.${ENDCOLOR}"
    exit 1
fi

if [[ ! -f "$PACKAGE_FILE" ]]; then
    printf '%s\n' "${RED}ERROR: packages.txt was not found at $PACKAGE_FILE.${ENDCOLOR}"
    printf '%s\n' "${RED}Clone the full repository or run this script with a complete copy of the project.${ENDCOLOR}"
    exit 1
fi

# Validate sudo privileges early so failures happen before package changes begin.
sudo true

mapfile -t REQUIRED_PACKAGES < <(grep -Ev '^[[:space:]]*(#|$)' "$PACKAGE_FILE")

if (( ${#REQUIRED_PACKAGES[@]} == 0 )); then
    printf '%s\n' "${RED}ERROR: No packages were found in $PACKAGE_FILE.${ENDCOLOR}"
    exit 1
fi

printf '%s\n' "${GREEN}Synchronizing packages and installing required printing/scanning support.${ENDCOLOR}"
# Use pacman Sy to avoid partial updates on Arch Linux.
sudo pacman -Sy --needed "${REQUIRED_PACKAGES[@]}"

printf '%s\n' "${YELLOW}Detecting desktop environment.${ENDCOLOR}"
DE="${XDG_CURRENT_DESKTOP:-}"
DE="${DE,,}"

# Install printing packages for KDE or GNOME.
if [[ "$DE" == *gnome* ]]; then
    printf '%s\n' "${GREEN}GNOME detected. Installing GNOME printing and scanning apps.${ENDCOLOR}"
    sudo pacman -S --needed simple-scan system-config-printer cups-pk-helper
elif [[ "$DE" == *kde* || "$DE" == *plasma* ]]; then
    printf '%s\n' "${GREEN}KDE Plasma detected. Installing KDE printing and scanning apps.${ENDCOLOR}"
    sudo pacman -S --needed skanlite print-manager
else
    printf '%s\n' "${YELLOW}Desktop environment not detected or not supported (${DE:-unknown}).${ENDCOLOR}"
    printf '%s\n' "${YELLOW}Please install a printer and scanner frontend manually for your desktop environment.${ENDCOLOR}"
fi

printf '%s\n' "${GREEN}Enabling services.${ENDCOLOR}"
# Use socket-based activation for CUPS to avoid slow boot times.
sudo systemctl enable --now cups.socket avahi-daemon.service ipp-usb.service

# Warn if systemd-resolved mDNS is active, as it can conflict with Avahi.
if systemctl is-active --quiet systemd-resolved; then
    RESOLVED_MDNS=$(resolvectl status 2>/dev/null | grep -im1 "MulticastDNS" || true)
    if [[ "${RESOLVED_MDNS,,}" =~ yes|active|enabled ]]; then
        printf '%s\n' "${YELLOW}WARNING: systemd-resolved has mDNS enabled, which can conflict with Avahi.${ENDCOLOR}"
        printf '%s\n' "${YELLOW}Network printer and scanner discovery may not work correctly.${ENDCOLOR}"
        printf '%s\n' "${YELLOW}Consider disabling systemd-resolved's mDNS by setting MulticastDNS=no in /etc/systemd/resolved.conf.d/${ENDCOLOR}"
    fi
fi

printf '%s\n' "${GREEN}Enabling network printer and scanner discovery.${ENDCOLOR}"

if [[ ! -e "$ORIGINAL_FILE" ]]; then
    printf '%s\n' "${RED}ERROR: $ORIGINAL_FILE is missing. Check if nss-mdns is installed.${ENDCOLOR}"
    printf '%s\n' "${RED}Exiting program.${ENDCOLOR}"
    exit 1
fi

BACKUP_FILE="${ORIGINAL_FILE}.arch-easyprint.bak"
printf '%s\n' "${GREEN}Creating a backup of $ORIGINAL_FILE at $BACKUP_FILE.${ENDCOLOR}"
sudo cp -a "$ORIGINAL_FILE" "$BACKUP_FILE"

CURRENT_HOSTS_LINE=$(grep -m1 '^hosts:' "$ORIGINAL_FILE" || true)

if [[ -z "$CURRENT_HOSTS_LINE" ]]; then
    NEW_HOSTS_LINE="hosts: files mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] myhostname dns"
elif [[ "$CURRENT_HOSTS_LINE" == *mdns_minimal* || "$CURRENT_HOSTS_LINE" == *mdns4_minimal* ]]; then
    NEW_HOSTS_LINE="$CURRENT_HOSTS_LINE"
    printf '%s\n' "${GREEN}mDNS hostname resolution is already configured in $ORIGINAL_FILE.${ENDCOLOR}"
elif [[ "$CURRENT_HOSTS_LINE" == *mymachines* ]]; then
    NEW_HOSTS_LINE="${CURRENT_HOSTS_LINE/mymachines/mymachines mdns_minimal [NOTFOUND=return]}"
else
    NEW_HOSTS_LINE="${CURRENT_HOSTS_LINE/hosts:/hosts: mdns_minimal [NOTFOUND=return]}"
fi

if [[ "$NEW_HOSTS_LINE" != "$CURRENT_HOSTS_LINE" ]]; then
    printf '%s\n' "${GREEN}Updating the hosts line in $ORIGINAL_FILE.${ENDCOLOR}"
    TEMP_FILE=$(mktemp)
    awk -v new_hosts_line="$NEW_HOSTS_LINE" '
        BEGIN { replaced = 0 }
        /^hosts:/ && replaced == 0 { print new_hosts_line; replaced = 1; next }
        { print }
        END { if (replaced == 0) print new_hosts_line }
    ' "$ORIGINAL_FILE" > "$TEMP_FILE"
    sudo cp "$TEMP_FILE" "$ORIGINAL_FILE"
    rm -f "$TEMP_FILE"
fi

# Verify the change.
if grep -qE '^hosts:.*mdns(4)?_minimal' "$ORIGINAL_FILE"; then
    printf '%s\n' "${GREEN}The hosts line has been successfully updated to: $NEW_HOSTS_LINE${ENDCOLOR}"
else
    printf '%s\n' "${RED}Failed to update the hosts line in $ORIGINAL_FILE${ENDCOLOR}"
    exit 1
fi

printf '%s\n' "${GREEN}Restarting CUPS to apply network discovery settings.${ENDCOLOR}"
sudo systemctl restart cups.service

printf '%s\n' "${GREEN}Configuring firewall rules.${ENDCOLOR}"
if systemctl is-active --quiet ufw; then
    printf '%s\n' "${GREEN}UFW detected. Opening required ports.${ENDCOLOR}"
    # UDP 5353 - mDNS for network printer and scanner discovery.
    sudo ufw allow 5353/udp
    # TCP 6566 - saned for network scanner sharing.
    sudo ufw allow 6566/tcp
    sudo ufw reload
elif systemctl is-active --quiet firewalld; then
    printf '%s\n' "${GREEN}firewalld detected. Opening required ports.${ENDCOLOR}"
    # UDP 5353 - mDNS for network printer and scanner discovery.
    sudo firewall-cmd --permanent --add-port=5353/udp
    # TCP 6566 - saned for network scanner sharing.
    sudo firewall-cmd --permanent --add-port=6566/tcp
    sudo firewall-cmd --reload
elif systemctl is-active --quiet iptables; then
    printf '%s\n' "${YELLOW}iptables detected. Please open the following ports manually:${ENDCOLOR}"
    printf '%s\n' "${YELLOW}  UDP 5353 - mDNS (network printer and scanner discovery)${ENDCOLOR}"
    printf '%s\n' "${YELLOW}  TCP 6566 - saned (network scanner sharing)${ENDCOLOR}"
else
    printf '%s\n' "${YELLOW}No active firewall detected. Skipping firewall configuration.${ENDCOLOR}"
fi

cat << EOF
Script has finished successfully!
Please make sure to add your printer through the CUPS at http://localhost:631/
or by using your desktop environment's printer app.
NOTE: Do not enable cups-browsed.service because it is not needed for DNS-SD/mDNS printer discovery and it can significantly slow down your boot time.
If your printer or scanner is not detected, try logging out and logging back in or restarting your computer and trying again.
EOF
