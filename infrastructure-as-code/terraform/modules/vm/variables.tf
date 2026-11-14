variable "name" {
  type = string
}

variable "vm_id" {
  description = "Must sit in the reserved lab range so it can never collide with existing guests."
  type        = number

  validation {
    condition     = var.vm_id >= 9000 && var.vm_id <= 9099
    error_message = "vm_id must be in the reserved lab range 9000-9099."
  }
}

variable "node_name" {
  type = string
}

variable "pool_id" {
  type = string

  validation {
    condition     = length(var.pool_id) > 0
    error_message = "pool_id is required: every lab VM lives in the scoped pool."
  }
}

variable "image_file_id" {
  type = string
}

variable "datastore_id" {
  type = string
}

variable "bridge" {
  type = string
}

variable "ipv4_cidr" {
  type = string

  validation {
    condition     = can(cidrhost(var.ipv4_cidr, 0))
    error_message = "ipv4_cidr must be an address in CIDR form, e.g. 192.168.50.10/24."
  }
}

variable "gateway" {
  type = string
}

variable "dns_servers" {
  type = list(string)
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 2048
}

variable "disk_gb" {
  type    = number
  default = 20
}


variable "admin_user" {
  type = string
}

variable "ssh_public_key" {
  type = string
}
