# Variables

variable "boot_command" {
  type = list (string)
  default = [
    "<enter><wait2>",
    "<enter><wait2>",
    "<f6><esc><wait2>",
    "autoinstall<wait2>",
    "<spacebar>",
    "ds=nocloud-net;<wait2>s=http://{{ .HTTPIP }}:<wait2>{{ .HTTPPort }}/<wait2>",
    "<enter>"
  ]
}

variable "boot_wait_virtualbox" {
  type    = string
  default = "5s"
}

variable "boot_wait_vmware" {
  type    = string
  default = "5s"
}

variable "cpus" {
  type    = string
  default = "1"
}

variable "desktop" {
  type    = string
  default = "false"
}

variable "disk_size" {
  type    = string
  default = "25000"
}

variable "headless" {
  type    = string
  default = "true"
}

variable "http_proxy" {
  type    = string
  default = "${env("http_proxy")}"
}

variable "https_proxy" {
  type    = string
  default = "${env("https_proxy")}"
}

variable "iso_checksum" {
  type    = string
  default = "https://releases.ubuntu.com/20.04/SHA256SUMS"
}

variable "iso_checksum_type" {
  type    = string
  default = "file"
}

variable "iso_name" {
  type    = string
  default = "ubuntu-20.04.4-live-server-amd64.iso"
}

variable "iso_path" {
  type    = string
  default = "iso"
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/20.04/ubuntu-20.04.4-live-server-amd64.iso"
}

variable "memory" {
  type    = string
  default = "4096"
}

variable "no_proxy" {
  type    = string
  default = "${env("no_proxy")}"
}

variable "ssh_handshake_attempts" {
  type    = string
  default = "100"
}

variable "ssh_password" {
  type    = string
  default = "Password1234"
}

variable "ssh_pty" {
  type    = string
  default = "true"
}

variable "ssh_timeout" {
  type    = string
  default = "30m"
}

variable "ssh_username" {
  type    = string
  default = "misp"
}

variable "update" {
  type    = string
  default = "true"
}

variable "vm_description" {
  type    = string
  default = "MISP, is an open source software solution for collecting, storing, distributing and sharing cyber security indicators and threat about cyber security incidents analysis and malware analysis. MISP is designed by and for incident analysts, security and ICT professionals or malware reverser to support their day-to-day operations to share structured informations efficiently."
}

variable "vm_name" {
  type    = string
  default = "MISP_demo"
}

variable "vm_version" {
  type    = string
  default = "2.4"
}