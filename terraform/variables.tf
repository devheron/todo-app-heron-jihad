// Parâmetro environment
variable "environment" {
  description = "Ambiente de destino"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "homolog", "prod"], var.environment)
    error_message = "environment deve ser dev, homolog ou prod."
  }
}

// Parâmetro location
variable "location" {
  description = "Região da Azure"
  type        = string
  default     = "eastus2"
}

// Parâmetro instance_name
variable "instance_name" {
  description = "Nome da VM da aplicação; a VM do banco recebe o sufixo -db"
  type        = string
  default     = "vm-pm04"
}

// Parâmetro instance_type
variable "instance_type" {
  description = "Tamanho da VM da aplicação"
  type        = string
  default     = "Standard_D2als_v6"
}

// Parâmetro db_instance_type
variable "db_instance_type" {
  description = "Tamanho da VM do banco"
  type        = string
  default     = "Standard_D2als_v6"
}

// Parâmetro admin_username
variable "admin_username" {
  description = "Usuário administrador das VMs, usado pelo Ansible"
  type        = string
  default     = "azureuser"
}

// Parâmetro ssh_public_key
variable "ssh_public_key" {
  description = "Chave pública SSH das VMs, vinda do secret SSH_PUBLIC_KEY"
  type        = string
}

// Parâmetro vnet_cidr
variable "vnet_cidr" {
  description = "Faixa da rede virtual"
  type        = string
  default     = "10.0.0.0/16"
}

// Parâmetro app_subnet_cidr
variable "app_subnet_cidr" {
  description = "Subnet da VM da aplicação"
  type        = string
  default     = "10.0.1.0/24"
}

// Parâmetro db_subnet_cidr
variable "db_subnet_cidr" {
  description = "Subnet privada da VM do banco"
  type        = string
  default     = "10.0.2.0/24"
}
