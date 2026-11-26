// Versão do Terraform e do provider da Azure
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

// Autenticação pelas variáveis ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID e ARM_SUBSCRIPTION_ID
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}
