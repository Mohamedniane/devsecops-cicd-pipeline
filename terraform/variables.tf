variable "iso_path" {
  type        = string
  description = "Chemin WSL2 vers l'ISO Ubuntu"
}
variable "host_only_adapter" {
  type        = string
  description = "Nom de l'interface Host-Only VirtualBox"
}
variable "vboxmanage_path" {
  type        = string
  description = "Chemin vers VBoxManage.exe"
}
variable "vm_basefolder_management" {
  type        = string
  description = "Dossier Windows pour VM-Management"
}
variable "vm_basefolder_gitlab" {
  type        = string
  description = "Dossier Windows pour VM1-GitLab"
}
variable "vm_basefolder_app" {
  type        = string
  description = "Dossier Windows pour VM2-App"
}
variable "vm_basefolder_wazuh" {
  type        = string
  description = "Dossier Windows pour VM3-Wazuh"
}
