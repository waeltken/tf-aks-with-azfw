variable "vm_username" {
  description = "username for the Virtual Machines"
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "path to the SSH public key file"
  default     = "~/.ssh/id_rsa.pub"
}
