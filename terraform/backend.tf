// State remoto no Storage Account criado fora do Terraform (rg-pm04)
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-pm04"
    storage_account_name = "tfstatepm04"
    container_name       = "tfstate"
    key                  = "pm04.terraform.tfstate"
  }
}
