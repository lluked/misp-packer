# Source blocks

source "virtualbox-iso" "ubuntu" {
  boot_command           = "${var.boot_command}"
  boot_wait              = "${var.boot_wait_virtualbox}"
  cpus                   = "${var.cpus}"
  disk_size              = "${var.disk_size}"
  export_opts            = [
    "--manifest", 
    "--vsys", "0", 
    "--description", "${var.vm_description}", 
    "--version", "${var.vm_version}" 
  ]
  format                 = "ova"
  gfx_controller         = "vmsvga"
  gfx_vram_size          = "32"
  guest_additions_path   = "VBoxGuestAdditions_{{ .Version }}.iso"
  guest_os_type          = "Ubuntu_64"
  hard_drive_interface   = "sata"
  headless               = "${var.headless}"
  http_directory         = "http"
  http_port_max          = 9011
  http_port_min          = 9001
  iso_checksum           = "${var.iso_checksum_type}:${var.iso_checksum}"
  iso_urls               = ["${var.iso_path}/${var.iso_name}", "${var.iso_url}"]
  memory                 = "${var.memory}"
  output_directory       = "output/${var.vm_name}_${trimsuffix(source.type, "-iso")}"
  shutdown_command       = "echo ${var.ssh_password} | sudo -S shutdown -P now"
  ssh_handshake_attempts = "${var.ssh_handshake_attempts}"
  ssh_password           = "${var.ssh_password}"
  ssh_pty                = "${var.ssh_pty}"
  ssh_timeout            = "${var.ssh_timeout}"
  ssh_username           = "${var.ssh_username}"
  vboxmanage             = [
    ["modifyvm", "{{ .Name }}", "--natpf1", "ssh,tcp,,2222,0.0.0.0,22"], 
    ["modifyvm", "{{ .Name }}", "--natpf1", "http,tcp,,8080,,80"], 
    ["modifyvm", "{{ .Name }}", "--natpf1", "https,tcp,,8443,,443"], 
    ["modifyvm", "{{ .Name }}", "--natpf1", "misp-modules,tcp,,1666,0.0.0.0,6666"], 
    ["modifyvm", "{{ .Name }}", "--vrde", "off"]
  ]
  vm_name                = "${var.vm_name}"
}

source "vmware-iso" "ubuntu" {
  boot_command           = "${var.boot_command}"
  boot_wait              = "${var.boot_wait_vmware}"
  disk_size              = "${var.disk_size}"
  guest_os_type          = "ubuntu-64"
  headless               = "${var.headless}"
  http_directory         = "http"
  http_port_max          = 9011
  http_port_min          = 9001
  iso_checksum           = "${var.iso_checksum_type}:${var.iso_checksum}"
  iso_urls               = ["${var.iso_path}/${var.iso_name}", "${var.iso_url}"]
  memory                 = "${var.memory}"
  output_directory       = "output/${var.vm_name}_${trimsuffix(source.type, "-iso")}"
  shutdown_command       = "echo ${var.ssh_password} |sudo -S shutdown -P now"
  skip_compaction        = false
  ssh_handshake_attempts = "${var.ssh_handshake_attempts}"
  ssh_password           = "${var.ssh_password}"
  ssh_pty                = "${var.ssh_pty}"
  ssh_timeout            = "${var.ssh_timeout}"
  ssh_username           = "${var.ssh_username}"
  vm_name                = "${var.vm_name}"
}

# Build blocks

build {
  sources = ["source.virtualbox-iso.ubuntu", "source.vmware-iso.ubuntu"]

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -E -S sh '{{ .Path }}'"
    scripts         = [
      "scripts/networking.sh",
      "scripts/extend.sh",
      "scripts/pre.sh"
    ]
  }

  provisioner "file" {
    destination = "/tmp/INSTALL.sh"
    source      = "scripts/INSTALL.sh"
  }

  provisioner "shell" {
    environment_vars = ["PACKER=1", "DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "echo '${var.ssh_password}' | {{ .Vars }} sudo -u ${var.ssh_username}  -E -S bash '{{ .Path }}'"
    inline           = ["chmod u+x /tmp/INSTALL.sh", "/tmp/INSTALL.sh -A -u"]
    pause_before     = "10s"
  }

  provisioner "file" {
    destination = "/tmp/crontab"
    source      = "conffiles/crontab"
  }

  provisioner "file" {
    destination = "/tmp/issue"
    source      = "conffiles/issue"
  }

  provisioner "shell" {
    execute_command   = "echo '${var.ssh_password}' | {{ .Vars }} sudo -E -S sh '{{ .Path }}'"
    expect_disconnect = "true"
    pause_after       = "30s"
    pause_before      = "10s"
    script            = "scripts/clean.sh"
  }

  post-processor "checksum" {
  checksum_types = ["sha256"]
  output = "output/${var.vm_name}_${trimsuffix(source.type, "-iso")}/${var.vm_name}_{{ .ChecksumType }}.checksum"
  }

}
