terraform {
  required_version = ">= 1.14.0"
  required_providers {
    null  = { source = "hashicorp/null",  version = "~> 3.2" }
    local = { source = "hashicorp/local", version = "~> 2.4" }
  }
}

module "vm_management" {
  source            = "./modules/virtualbox_vm"
  vm_name           = "VM-Management"
  memory_mb         = 2048
  disk_size_mb      = 20480
  vm_basefolder     = var.vm_basefolder_management
  iso_path          = var.iso_path
  static_ip         = "192.168.137.5"
  host_only_adapter = var.host_only_adapter
  vboxmanage_path   = var.vboxmanage_path
}

module "vm1_gitlab" {
  source            = "./modules/virtualbox_vm"
  vm_name           = "VM1-GitLab"
  memory_mb         = 6144
  disk_size_mb      = 51200
  vm_basefolder     = var.vm_basefolder_gitlab
  iso_path          = var.iso_path
  static_ip         = "192.168.137.10"
  host_only_adapter = var.host_only_adapter
  vboxmanage_path   = var.vboxmanage_path
  depends_on        = [module.vm_management]
}

module "vm2_app" {
  source            = "./modules/virtualbox_vm"
  vm_name           = "VM2-Application"
  memory_mb         = 4096
  disk_size_mb      = 30720
  vm_basefolder     = var.vm_basefolder_app
  iso_path          = var.iso_path
  static_ip         = "192.168.137.20"
  host_only_adapter = var.host_only_adapter
  vboxmanage_path   = var.vboxmanage_path
  depends_on        = [module.vm_management]
}

module "vm3_wazuh" {
  source            = "./modules/virtualbox_vm"
  vm_name           = "VM3-Wazuh"
  memory_mb         = 8192
  disk_size_mb      = 51200
  vm_basefolder     = var.vm_basefolder_wazuh
  iso_path          = var.iso_path
  static_ip         = "192.168.137.30"
  host_only_adapter = var.host_only_adapter
  vboxmanage_path   = var.vboxmanage_path
  depends_on        = [module.vm_management]
}

resource "local_file" "ansible_inventory" {
  depends_on = [module.vm1_gitlab, module.vm2_app, module.vm3_wazuh]
  content    = templatefile("${path.module}/templates/hosts.tpl", {
    vm1_ip = "192.168.137.10"
    vm2_ip = "192.168.137.20"
    vm3_ip = "192.168.137.30"
  })
  filename   = "../ansible/inventory/hosts.ini"
}
