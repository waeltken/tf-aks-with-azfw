locals {
  location = "West Europe"
}

resource "azurerm_resource_group" "example" {
  name     = "aks-with-azfw-rg"
  location = local.location
}

resource "azurerm_virtual_network" "vnet_1" {
  name                = "vnet-hub"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["172.16.0.0/16"]
}

resource "azurerm_subnet" "subnet_1_1" {
  name                 = "subnet-hub-1"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet_1.name
  address_prefixes     = ["172.16.1.0/24"]
}

resource "azurerm_subnet" "subnet_1_2" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet_1.name
  address_prefixes     = ["172.16.2.0/24"]
}

resource "azurerm_virtual_network" "vnet_2" {
  name                = "vnet-spoke"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["172.32.0.0/16"]
}

resource "azurerm_subnet" "subnet_2_1" {
  name                 = "subnet-spoke-1"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet_2.name
  address_prefixes     = ["172.32.1.0/24"]
}

resource "azurerm_virtual_network_peering" "peering_1_to_2" {
  name                         = "vnet-peering"
  resource_group_name          = azurerm_resource_group.example.name
  virtual_network_name         = azurerm_virtual_network.vnet_1.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_2.id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "peering_2_to_1" {
  name                         = "vnet-peering"
  resource_group_name          = azurerm_resource_group.example.name
  virtual_network_name         = azurerm_virtual_network.vnet_2.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_1.id
  allow_virtual_network_access = true
}

