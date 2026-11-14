# Ubuntu 24.04 LTS cloud image in the "import" content type, so disks are imported
# through the API with no SSH or root access.
#
# By default the image is downloaded once by an admin (see docs/runbook.md) and only
# referenced here, which keeps Sys.Modify off the automation token. Set
# manage_image = true to let OpenTofu download it instead.
resource "proxmox_download_file" "ubuntu_noble" {
  count = var.manage_image ? 1 : 0

  node_name    = var.node_name
  datastore_id = var.image_datastore
  content_type = "import"
  file_name    = "noble-server-cloudimg-amd64.qcow2"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  overwrite    = false
}

locals {
  image_id = var.manage_image ? proxmox_download_file.ubuntu_noble[0].id : var.image_file_id
}

module "vm" {
  source   = "./modules/vm"
  for_each = var.vms

  name           = each.key
  vm_id          = each.value.vm_id
  node_name      = var.node_name
  pool_id        = var.pool_id
  image_file_id  = local.image_id
  datastore_id   = var.vm_datastore
  bridge         = var.bridge
  ipv4_cidr      = each.value.ipv4_cidr
  gateway        = var.gateway
  dns_servers    = var.dns_servers
  cores          = each.value.cores
  memory_mb      = each.value.memory_mb
  disk_gb        = each.value.disk_gb
  admin_user     = var.admin_user
  ssh_public_key = var.ssh_public_key
}
