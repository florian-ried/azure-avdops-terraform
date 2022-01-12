#backend edit
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "tfstate070122"
    container_name       = "tfstate"
    key                  = "azure-avdops-terraform.tfstate"
  }
}