#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
if ! cd "$SCRIPT_DIR"; then
    echo "Unable to cd to install.sh script dir. Check permissions."
    exit 1
fi

if ! sudo true; then
    echo "Root permissions are required to run this script."
    exit 2
fi

if [ ! -f "config.inc.sh" ]; then
    "config.inc.sh not found. Please make a copy of the example file and add your configuration"
    exit 3
fi

sudo cp config.inc.sh /etc/NetworkManager/dispatcher.d/per-if-tables.sh
sudo bash -c "cat per-if-tables.sh >> /etc/NetworkManager/dispatcher.d/per-if-tables.sh"
sudo chmod 744 /etc/NetworkManager/dispatcher.d/per-if-tables.sh
sudo systemctl restart NetworkManager
