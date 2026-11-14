resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  vm_id     = var.vm_id
  node_name = var.node_name
  pool_id   = var.pool_id

  # No tags: Proxmox checks tag permission on /vms/<id> before the new VM joins its
  # pool, so a pool-scoped token cannot set tags at create time. Ownership is shown by
  # pool membership and this description instead.
  description = "Managed by OpenTofu (homelab-iac). Manual changes will be overwritten."

  started         = true
  on_boot         = false
  stop_on_destroy = true

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    import_from  = var.image_file_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk_gb
  }

  network_device {
    bridge = var.bridge
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = var.ipv4_cidr
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      username = var.admin_user
      keys     = [trimspace(var.ssh_public_key)]
    }
  }
}
