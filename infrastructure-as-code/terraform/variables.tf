variable "proxmox_insecure" {
  description = "Skip TLS verification (only for a self-signed Proxmox cert on a trusted LAN)."
  type        = bool
  default     = false
}

variable "node_name" {
  description = "Proxmox node that hosts the lab VMs."
  type        = string
}

variable "pool_id" {
  description = "Resource pool the API token is scoped to. Every VM is created inside it."
  type        = string
  default     = "iac-lab"
}

variable "manage_image" {
  description = "Let OpenTofu download the cloud image (needs extra node privileges on the token)."
  type        = bool
  default     = false
}

variable "image_file_id" {
  description = "Existing cloud image volume, used when manage_image = false."
  type        = string
  default     = "local:import/noble-server-cloudimg-amd64.qcow2"
}

variable "image_datastore" {
  description = "Datastore with the 'import' content type for the cloud image."
  type        = string
  default     = "local"
}

variable "vm_datastore" {
  description = "Datastore for VM disks."
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge for lab VMs."
  type        = string
  default     = "vmbr0"
}

variable "gateway" {
  description = "IPv4 gateway for lab VMs."
  type        = string
}

variable "dns_servers" {
  description = "DNS servers for lab VMs."
  type        = list(string)
}

variable "ssh_public_key" {
  description = "Public key injected for the admin user."
  type        = string
}

variable "admin_user" {
  description = "Admin username created by cloud-init."
  type        = string
  default     = "labadmin"
}

variable "vms" {
  description = "Lab VMs keyed by name."
  type = map(object({
    vm_id     = number
    ipv4_cidr = string
    cores     = optional(number, 2)
    memory_mb = optional(number, 2048)
    disk_gb   = optional(number, 20)
  }))
}
