locals {
  location           = "West Europe"
  aks_version_prefix = "1.22"
}

resource "azurerm_resource_group" "example" {
  name     = "aks-with-azfw-rg"
  location = local.location
}

# Basic Network Setup
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

# Create Firewall
resource "azurerm_public_ip" "fwip" {
  name                = "testfwpip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "example" {
  name                = "testfirewall"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  dns_servers = ["8.8.8.8"]

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subnet_1_2.id
    public_ip_address_id = azurerm_public_ip.fwip.id
  }
}

# Create routing table for AKS subnet
resource "azurerm_route_table" "egress" {
  name                          = "fwrt"
  location                      = azurerm_resource_group.example.location
  resource_group_name           = azurerm_resource_group.example.name
  disable_bgp_route_propagation = false

  route {
    name                   = "fwrn"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.example.ip_configuration[0].private_ip_address
  }

  route {
    name           = "fwinternet"
    address_prefix = "${azurerm_public_ip.fwip.ip_address}/32"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "egress" {
  subnet_id      = azurerm_subnet.subnet_2_1.id
  route_table_id = azurerm_route_table.egress.id
}

# Firewall Rules needed by AKS
resource "azurerm_firewall_network_rule_collection" "aks" {
  name                = "aksfwnr"
  azure_firewall_name = azurerm_firewall.example.name
  resource_group_name = azurerm_resource_group.example.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "apiudp"
    # Can be scoped to aks subnet
    source_addresses = [
      "*",
    ]
    destination_ports = [
      "1194",
    ]
    destination_addresses = [
      "AzureCloud.${azurerm_resource_group.example.location}"
    ]
    protocols = [
      "UDP",
    ]
  }

  rule {
    name = "apitcp"
    # Can be scoped to aks subnet
    source_addresses = [
      "*",
    ]
    destination_ports = [
      "9000",
    ]
    destination_addresses = [
      "AzureCloud.${azurerm_resource_group.example.location}"
    ]
    protocols = [
      "TCP",
    ]
  }

  rule {
    name = "time"
    # Can be scoped to aks subnet
    source_addresses = [
      "*",
    ]
    destination_ports = [
      "123",
    ]
    destination_fqdns = ["ntp.ubuntu.com"]
    protocols = [
      "UDP",
    ]
  }

}

# Application Policy Needed by AKS
resource "azurerm_firewall_application_rule_collection" "aks" {
  name                = "aksfwar"
  azure_firewall_name = azurerm_firewall.example.name
  resource_group_name = azurerm_resource_group.example.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "fqdn"

    # Can be scoped to aks subnet
    source_addresses = [
      "*",
    ]

    fqdn_tags = ["AzureKubernetesService"]

    # protocol {
    #   port = "443"
    #   type = "Https"
    # }

    # protocol {
    #   port = "80"
    #   type = "Http"
    # }
  }
}

resource "azurerm_firewall_nat_rule_collection" "inbound" {
  name                = "inboundcollection"
  azure_firewall_name = azurerm_firewall.example.name
  resource_group_name = azurerm_resource_group.example.name
  priority            = 100
  action              = "Dnat"

  rule {
    name = "inboundrulehttp"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "80",
    ]

    destination_addresses = [
      azurerm_public_ip.fwip.ip_address
    ]

    translated_port = 80

    translated_address = var.internal_loadbalancer_ip

    protocols = [
      "TCP",
      "UDP",
    ]
  }

  rule {
    name = "inboundrulehttps"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "443",
    ]

    destination_addresses = [
      azurerm_public_ip.fwip.ip_address
    ]

    translated_port = 443

    translated_address = var.internal_loadbalancer_ip

    protocols = [
      "TCP",
      "UDP",
    ]
  }
}

data "azurerm_kubernetes_service_versions" "current" {
  location       = azurerm_resource_group.example.location
  version_prefix = local.aks_version_prefix
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = "aks-with-azfw"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "aks-with-azfw-sample"

  kubernetes_version = data.azurerm_kubernetes_service_versions.current.latest_version

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_B4ms"
    vnet_subnet_id = azurerm_subnet.subnet_2_1.id
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting"
  }

  depends_on = [
    azurerm_subnet_route_table_association.egress
  ]
}
