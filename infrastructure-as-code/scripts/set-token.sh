#!/usr/bin/env bash
# Stores the Proxmox API token in a private env file (mode 600) without echoing it.
set -euo pipefail
dir="$HOME/.config/homelab-iac"; file="$dir/env"
mkdir -p "$dir"; chmod 700 "$dir"
read -rp "Proxmox endpoint (e.g. https://pve.example.lan:8006/): " ep
[ -n "$ep" ] || { echo "Endpoint required" >&2; exit 1; }
read -rsp "Paste the token secret (UUID only, input hidden): " secret; echo
umask 077
printf 'PROXMOX_VE_ENDPOINT=%q\nPROXMOX_VE_API_TOKEN=%q\n' "$ep" "tofu@pve!iac=$secret" > "$file"
chmod 600 "$file"
echo "Saved to $file (mode 600)."
