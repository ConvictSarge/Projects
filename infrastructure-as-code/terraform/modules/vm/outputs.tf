output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}

output "ipv4" {
  value = split("/", var.ipv4_cidr)[0]
}
