variable "vm_name" {
  type = string
}
variable "memory_mb" {
  type = number
}
variable "cpus" {
  type    = number
  default = 2
}
variable "disk_size_mb" {
  type = number
}
variable "iso_path" {
  type = string
}
variable "static_ip" {
  type = string
}
variable "host_only_adapter" {
  type = string
}
variable "vboxmanage_path" {
  type = string
}
variable "vm_basefolder" {
  type    = string
  default = ""
}
