# Credentials come from the environment, never from files in this repo:
#   PROXMOX_VE_ENDPOINT   e.g. https://pve.example.lan:8006/
#   PROXMOX_VE_API_TOKEN  e.g. tofu@pve!iac=<secret>
#
# API only: no SSH block, so the provider never needs root SSH on a node.
provider "proxmox" {
  insecure = var.proxmox_insecure
}
