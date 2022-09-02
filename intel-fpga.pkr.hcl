build {
  post-processor "shell-local" {
    command = "virt-sysprep --add output/${source.name}/${source.name}.qcow2 --operations defaults,-customize"
    execute_command = [
      "sudo",
      "sh",
      "{{ .Script }}"
    ]
  }
  post-processor "checksum" {
    checksum_types = [
      "sha256"
    ]
    output = "output/checksums.txt"
  }
  provisioner "shell" {
    execute_command = "sudo sh {{ .Path }}"
    scripts = [
      "scripts/pac_a10/intel-fpga.sh"
    ]
  }
  source "qemu.centos7" {
    name = "intel-fpga-pac_a10-centos7"
  }
  source "qemu.ubuntu1804" {
    name = "intel-fpga-pac_a10-ubuntu1804"
  }
}

build {
  post-processor "shell-local" {
    command = "virt-sysprep --add output/${source.name}/${source.name}.qcow2 --operations defaults,-customize"
    execute_command = [
      "sudo",
      "sh",
      "{{ .Script }}"
    ]
  }
  post-processor "checksum" {
    checksum_types = [
      "sha256"
    ]
    output = "output/checksums.txt"
  }
  provisioner "shell" {
    execute_command = "sudo sh {{ .Path }}"
    scripts = [
      "scripts/pac_s10/intel-fpga.sh"
    ]
  }
  source "qemu.centos7" {
    name = "intel-fpga-pac_s10-centos7"
  }
}

data "sshkey" "temporary" {}

packer {
  required_plugins {
    openstack = {
      source  = "github.com/ivoronin/sshkey"
      version = ">= 1.0.0"
    }
  }
}

source "qemu" "centos7" {
  cd_content = {
    "meta-data" = ""
    "user-data" = join("\n", [
      "#cloud-config",
      yamlencode({
        ssh_authorized_keys = [
          data.sshkey.temporary.public_key
        ]
      })
    ])
  }
  cd_label                  = "cidata"
  disk_compression          = true
  disk_image                = true
  headless                  = true
  iso_checksum              = "file:https://cloud.centos.org/centos/7/images/sha256sum.txt"
  iso_url                   = "https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-1907.qcow2"
  output_directory          = "output/${source.name}"
  ssh_clear_authorized_keys = true
  ssh_private_key_file      = data.sshkey.temporary.private_key_path
  ssh_username              = "centos"
  shutdown_command          = "sudo shutdown now"
  temporary_key_pair_name   = "packer"
  vm_name                   = "${source.name}.qcow2"
}

source "qemu" "ubuntu1804" {
  cd_content = {
    "meta-data" = ""
    "user-data" = join("\n", [
      "#cloud-config",
      yamlencode({
        ssh_authorized_keys = [
          data.sshkey.temporary.public_key
        ]
      })
    ])
  }
  cd_label                  = "cidata"
  disk_compression          = true
  disk_image                = true
  headless                  = true
  iso_checksum              = "file:https://cloud-images.ubuntu.com/bionic/current/SHA256SUMS"
  iso_url                   = "https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
  output_directory          = "output/${source.name}"
  ssh_clear_authorized_keys = true
  ssh_private_key_file      = data.sshkey.temporary.private_key_path
  ssh_username              = "ubuntu"
  shutdown_command          = "sudo shutdown now"
  temporary_key_pair_name   = "packer"
  vm_name                   = "${source.name}.qcow2"
}
