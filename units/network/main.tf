# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

# Azure network scaffolding for the cluster: resource group, virtual network,
# subnet, security group, and the Juju model. The NFS share and the Slurm
# deployment are set up at the Terragrunt level (see
# `deployments/azure/slurm/nfs` and `deployments/azure/slurm/slurm`).

resource "azurerm_resource_group" "nfs-group" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "nfs-vnet" {
  name                = "nfs-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.nfs-group.location
  resource_group_name = azurerm_resource_group.nfs-group.name
  subnet              = []
}

resource "azurerm_network_security_group" "nfs-nsg" {
  name                = "nfs-nsg"
  location            = azurerm_resource_group.nfs-group.location
  resource_group_name = azurerm_resource_group.nfs-group.name
  security_rule {
    name                       = "Allow-SSH-Internet"
    description                = "Open SSH inbound ports"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
    access                     = "Allow"
    priority                   = 100
    direction                  = "Inbound"
  }
}

resource "azurerm_subnet" "nfs-subnet" {
  name                                          = "nfs-subnet"
  resource_group_name                           = azurerm_resource_group.nfs-group.name
  virtual_network_name                          = azurerm_virtual_network.nfs-vnet.name
  address_prefixes                              = ["10.0.1.0/24"]
  private_endpoint_network_policies             = "Enabled"
  private_link_service_network_policies_enabled = true
}

resource "azurerm_subnet_network_security_group_association" "nfs-nsg-to-subnet" {
  subnet_id                 = azurerm_subnet.nfs-subnet.id
  network_security_group_id = azurerm_network_security_group.nfs-nsg.id
}

resource "juju_model" "charmed-hpc" {
  name = var.model_name

  cloud {
    name   = "azure"
    region = var.region
  }

  config = {
    resource-group-name = azurerm_resource_group.nfs-group.name
    network             = azurerm_virtual_network.nfs-vnet.name
    # Needed to work around azure storage pool requests hanging. MySQL deployment gets stuck at
    # "agent initialising" otherwise.
    storage-default-filesystem-source = "rootfs"
  }
}
