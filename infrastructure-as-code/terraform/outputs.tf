output "vms" {
  description = "Lab VMs and their addresses (feed into the Ansible inventory)."
  value = {
    for name, vm in module.vm : name => {
      vm_id = vm.vm_id
      ipv4  = vm.ipv4
    }
  }
}
