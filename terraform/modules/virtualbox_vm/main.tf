locals { vbm = var.vboxmanage_path }

# 1. Création de la VM
resource "null_resource" "create_vm" {
  triggers = {
    vm_name         = var.vm_name
    vboxmanage_path = var.vboxmanage_path
  }
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      if "${local.vbm}" list vms | grep -q '"${var.vm_name}"'; then
        echo "[INFO] VM ${var.vm_name} existe déjà"; exit 0
      fi
      "${local.vbm}" createvm \
        --name "${var.vm_name}" \
        --ostype Ubuntu_64 \
        --basefolder "${var.vm_basefolder}" \
        --register
    EOT
  }
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      "${self.triggers.vboxmanage_path}" controlvm "${self.triggers.vm_name}" poweroff 2>/dev/null || true
      sleep 5
      "${self.triggers.vboxmanage_path}" unregistervm "${self.triggers.vm_name}" --delete 2>/dev/null || true
    EOT
  }
}

# 2. Configuration hardware
resource "null_resource" "configure_hardware" {
  depends_on = [null_resource.create_vm]
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      "${local.vbm}" modifyvm "${var.vm_name}" \
        --memory ${var.memory_mb} --cpus ${var.cpus} \
        --boot1 dvd --boot2 disk --audio none --usb off
    EOT
  }
}

# 3. Création du disque VDI directement sur D:
resource "null_resource" "create_disk" {
  depends_on = [null_resource.configure_hardware]
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      VDI="${var.vm_basefolder}\\${var.vm_name}.vdi"
      "${local.vbm}" createmedium disk \
        --filename "$VDI" \
        --size ${var.disk_size_mb} \
        --format VDI --variant Standard 2>/dev/null || true
      "${local.vbm}" storagectl "${var.vm_name}" \
        --name "SATA" --add sata 2>/dev/null || true
      "${local.vbm}" storageattach "${var.vm_name}" \
        --storagectl "SATA" --port 0 --device 0 \
        --type hdd --medium "$VDI" 2>/dev/null || true
    EOT
  }
}

# 4. Attacher l'ISO
resource "null_resource" "attach_iso" {
  depends_on = [null_resource.create_disk]
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      "${local.vbm}" storagectl "${var.vm_name}" \
        --name "IDE" --add ide 2>/dev/null || true
      "${local.vbm}" storageattach "${var.vm_name}" \
        --storagectl "IDE" --port 0 --device 0 \
        --type dvddrive --medium "${var.iso_path}" 2>/dev/null || true
    EOT
  }
}

# 5. Configuration réseau
resource "null_resource" "configure_network" {
  depends_on = [null_resource.attach_iso]
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      "${local.vbm}" modifyvm "${var.vm_name}" \
        --nic1 hostonly \
        --hostonlyadapter1 "${var.host_only_adapter}" \
        --nictype1 82540EM \
        --nic2 nat \
        --nictype2 82540EM
    EOT
  }
}

# 6. Démarrage en mode GUI
resource "null_resource" "start_vm" {
  depends_on = [null_resource.configure_network]
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      STATE=$("${local.vbm}" showvminfo "${var.vm_name}" \
        --machinereadable | grep "^VMState=" | cut -d'"' -f2)
      if [ "$STATE" != "running" ]; then
        "${local.vbm}" startvm "${var.vm_name}" --type gui
        echo "[OK] ${var.vm_name} démarrée — IP cible : ${var.static_ip}"
      fi
    EOT
  }
}
