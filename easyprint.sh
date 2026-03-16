#!/bin/bash
set -euo pipefail

# Define color variables
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
ENDCOLOR=$'\033[0m'

cat << EOF
Welcome to Arch-EasyPrint!
This script will install the required packages and dependencies to have your printer and scanner up and running.
EOF

while true; do
    read -r -p "Do you want to continue? (Y/N): " response
    case "$response" in
        [Yy])
            printf '%s\n' "${YELLOW}You responded with Y. Continuing.${ENDCOLOR}"
            break
            ;;
        [Nn])
            printf '%s\n' "${YELLOW}You responded with N. Exiting.${ENDCOLOR}"
            exit 1
            ;;
        *)
            printf '%s\n' "${YELLOW}Invalid response. Please enter Y or N.${ENDCOLOR}"
            ;;
    esac
done

printf '%s\n' "${GREEN}Updating Pacman package database.${ENDCOLOR}"
sudo pacman -Syy

printf '%s\n' "${GREEN}Installing required packages.${ENDCOLOR}"
sudo pacman -S --needed - < packages.txt

printf '%s\n' "${GREEN}Detecting desktop environment.${ENDCOLOR}"
DE="${XDG_CURRENT_DESKTOP:-}"
DE="${DE,,}"

if [[ "$DE" == *gnome* ]]; then
    printf '%s\n' "${GREEN}GNOME detected. Installing GNOME printing and scanning apps.${ENDCOLOR}"
    sudo pacman -S --needed simple-scan system-config-printer cups-pk-helper
elif [[ "$DE" == *kde* ]]; then
    printf '%s\n' "${GREEN}KDE detected. Installing KDE printing and scanning apps.${ENDCOLOR}"
    sudo pacman -S --needed skanlite print-manager
else
    printf '%s\n' "${YELLOW}Desktop environment not detected or not supported (${DE}).${ENDCOLOR}"
    printf '%s\n' "${YELLOW}Please install a printer and scanner frontend manually for your desktop environment.${ENDCOLOR}"
fi

printf '%s\n' "${GREEN}Updating Gutenprint PPD files.${ENDCOLOR}"
sudo cups-genppdupdate

printf '%s\n' "${GREEN}Enabling services.${ENDCOLOR}"
# Use socket-based activation for CUPS to avoid slow boot times.
# cups.socket starts CUPS on demand; cups.service is not enabled at boot.
sudo systemctl enable --now cups.socket avahi-daemon.service ipp-usb.service

# Warn if systemd-resolved mDNS is active, as it conflicts with Avahi
if systemctl is-active --quiet systemd-resolved; then
    RESOLVED_MDNS=$(resolvectl status 2>/dev/null | grep -im1 "MulticastDNS" || true)
    if [[ "$RESOLVED_MDNS" =~ yes|active|enabled ]]; then
        printf '%s\n' "${YELLOW}WARNING: systemd-resolved has mDNS enabled, which conflicts with Avahi.${ENDCOLOR}"
        printf '%s\n' "${YELLOW}Network printer and scanner discovery may not work correctly.${ENDCOLOR}"
        printf '%s\n' "${YELLOW}Consider disabling systemd-resolved's mDNS by setting MulticastDNS=no in /etc/systemd/resolved.conf${ENDCOLOR}"
    fi
fi

printf '%s\n' "${GREEN}Enabling network printer and scanner discovery.${ENDCOLOR}"

ORIGINAL_FILE="/etc/nsswitch.conf"
BACKUP_FILE="/etc/nsswitch.conf.backup"

# Check if original file exists
if [[ ! -e "$ORIGINAL_FILE" ]]; then
    printf '%s\n' "${RED}ERROR: $ORIGINAL_FILE is missing. Check if nss-mdns is installed.${ENDCOLOR}"
    printf '%s\n' "${RED}Exiting program.${ENDCOLOR}"
    exit 1
fi

# Check if there's a backup file
if [[ -e "$BACKUP_FILE" ]]; then
    printf '%s\n' "${RED}ERROR: Backup file already exists. Please delete this file or rename it.${ENDCOLOR}"
    printf '%s\n' "${RED}Exiting program.${ENDCOLOR}"
    exit 1
fi

# Proceed if requirements are met
echo "Creating a backup of $ORIGINAL_FILE"
sudo cp "$ORIGINAL_FILE" "$BACKUP_FILE"
echo "Successfully created backup as $BACKUP_FILE"

NEW_HOSTS_LINE="hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns"

printf '%s\n' "${GREEN}Adding 'hosts' parameters to nsswitch.conf${ENDCOLOR}"

# Replace the hosts line in nsswitch.conf
if grep -q "^hosts:" "$ORIGINAL_FILE"; then
    sudo sed -i "s|^hosts:.*|$NEW_HOSTS_LINE|" "$ORIGINAL_FILE"
    echo "The hosts line in $ORIGINAL_FILE has been replaced."
else
    echo "$NEW_HOSTS_LINE" | sudo tee -a "$ORIGINAL_FILE" > /dev/null
    echo "The hosts line did not exist in $ORIGINAL_FILE. It has been added."
fi

# Verify the change
if grep -qF "$NEW_HOSTS_LINE" "$ORIGINAL_FILE"; then
    echo "The hosts line has been successfully updated to: $NEW_HOSTS_LINE"
else
    printf '%s\n' "${RED}Failed to update the hosts line in $ORIGINAL_FILE${ENDCOLOR}"
fi

printf '%s\n' "${GREEN}Restarting CUPS to apply network discovery settings.${ENDCOLOR}"
sudo systemctl restart cups.service

printf '%s\n' "${GREEN}Configuring firewall rules.${ENDCOLOR}"
if systemctl is-active --quiet ufw; then
    printf '%s\n' "${GREEN}UFW detected. Opening required ports.${ENDCOLOR}"
    # UDP 5353 - mDNS for network printer and scanner discovery
    sudo ufw allow 5353/udp
    # TCP 6566 - saned for network scanner sharing
    sudo ufw allow 6566/tcp
    sudo ufw reload
elif systemctl is-active --quiet firewalld; then
    printf '%s\n' "${GREEN}firewalld detected. Opening required ports.${ENDCOLOR}"
    # UDP 5353 - mDNS for network printer and scanner discovery
    sudo firewall-cmd --permanent --add-port=5353/udp
    # TCP 6566 - saned for network scanner sharing
    sudo firewall-cmd --permanent --add-port=6566/tcp
    sudo firewall-cmd --reload
elif systemctl is-active --quiet iptables; then
    printf '%s\n' "${YELLOW}iptables detected. Please open the following ports manually:${ENDCOLOR}"
    printf '%s\n' "${YELLOW}  UDP 5353 — mDNS (network printer and scanner discovery)${ENDCOLOR}"
    printf '%s\n' "${YELLOW}  TCP 6566 — saned (network scanner sharing)${ENDCOLOR}"
else
    printf '%s\n' "${YELLOW}No active firewall detected. Skipping firewall configuration.${ENDCOLOR}"
fi

cat << EOF
Script finished successfully!
Please be sure to add your printer through the CUPS web interface at http://localhost:631/
or using your desktop environment's printer settings.
NOTE: Do not enable cups-browsed.service because it's not needed for DNS-SD/mDNS printer discovery and it will significantly slow down your boot time.
If your printer or scanner is not detected, try logging out and logging back in or restarting your computer and trying again.
EOF
