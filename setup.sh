#!/bin/bash

# Define color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
ENDCOLOR='\033[0m'

cat << EOF
Welcome to Arch-EasyPrint!
This script will install the required packages and dependencies to have your printer up and running.
EOF

while true; do
    read -r -p "Do you want to continue? (Y/N): " response
    case "$response" in
        [Yy])
            echo -e "${YELLOW}You responded with Y. Continuing...${ENDCOLOR}"
            break
            ;;
        [Nn])
            echo -e "${YELLOW}You responded with N. Exiting...${ENDCOLOR}"
            exit 0
            ;;
        *)
            echo -e "${YELLOW}Invalid response. Please enter Y or N.${ENDCOLOR}"
            ;;
    esac
done

echo -e "${GREEN}Updating Pacman package database...${ENDCOLOR}"
sudo pacman -Syy

echo -e "${GREEN}Installing required packages...${ENDCOLOR}"
sudo pacman -S --needed - < packages.txt

echo -e "${GREEN}Enabling services...${ENDCOLOR}"
echo "Enabling cups.socket"
echo "Enabling avahi-daemon.service"
sudo systemctl enable --now cups.socket avahi-daemon.service

echo -e "${GREEN}Enabling printer network discovery...${ENDCOLOR}"

ORIGINAL_FILE="/etc/nsswitch.conf"
BACKUP_FILE="/etc/nsswitch.conf.backup"

# Check if original file exists
if [ ! -e "$ORIGINAL_FILE" ]; then
    echo -e "${RED}ERROR: $ORIGINAL_FILE is missing. Check if nss-mdns is installed.${ENDCOLOR}"
    echo -e "${RED}Exiting program.${ENDCOLOR}"
    exit 1
fi

# Check if there's a backup file
if [ -e "$BACKUP_FILE" ]; then
    echo -e "${RED}ERROR: Backup file already exists. Please delete this file or rename it.${ENDCOLOR}"
    echo -e "${RED}Exiting program.${ENDCOLOR}"
    exit 1
fi

# Proceed if requirements are met
echo "Creating a backup of $ORIGINAL_FILE"
sudo cp "$ORIGINAL_FILE" "$BACKUP_FILE"
echo "Successfully created backup as $BACKUP_FILE"

NEW_HOSTS_LINE="hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns"

echo -e "${GREEN}Adding 'hosts' parameters to nsswitch.conf${ENDCOLOR}"

# Replace the hosts line in nsswitch.conf
if grep -q "^hosts:" "$ORIGINAL_FILE"; then
    sudo sed -i "s|^hosts:.*|$NEW_HOSTS_LINE|" "$ORIGINAL_FILE"
    echo "The hosts line in $ORIGINAL_FILE has been replaced."
else
    echo "$NEW_HOSTS_LINE" | sudo tee -a "$ORIGINAL_FILE" > /dev/null
    echo "The hosts line did not exist in $ORIGINAL_FILE. It has been added."
fi

# Verify the change
if grep -q "^hosts: mymachines mdns_minimal \[NOTFOUND=return\] resolve \[!UNAVAIL=return\] files myhostname dns" "$ORIGINAL_FILE"; then
    echo "The hosts line has been successfully updated to: $NEW_HOSTS_LINE"
else
    echo -e "${RED}Failed to update the hosts line in $ORIGINAL_FILE${ENDCOLOR}"
fi

cat << EOF
Script finished successfully!
Please be sure to add your printer through the CUPS interface or using your desktop environment's GUI.
If that doesn't work, try logging out and logging back in or restarting your computer and trying again.
EOF
