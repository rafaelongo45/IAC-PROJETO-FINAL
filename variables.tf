variable "resource_group_location" {
  type        = string
  default     = "eastus"
  description = "Local onde o grupo de recursos sera criado"
}

variable "resource_group_name" {
  type        = string
  default     = "student-rg"
  description = "Prefixo que sera anexado ao nome randomico de grupo de recursos"
}

variable "username" {
  type        = string
  description = "O usuario que sera usado para nos conectarmos nas VMs"
  default     = "azureuser"
}

variable "number_resources" {
  type        = number
  default     = 1
  description = "Numero de VMs que serao criadas"
}

variable "vm_admin_password" {
  type        = string
  description = "A senha que será usada para conectar na vm"
  default     = "SENHA@SECRETA@NUNCAUSADA123"
}