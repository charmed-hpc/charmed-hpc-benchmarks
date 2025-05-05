# Copyright 2025 Canonical Ltd.
# See LICENSE file for licensing details.
terraform {
  required_providers {
    juju = {
      source  = "juju/juju"
      version = ">= 0.14.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.17"
    }
  }
}

provider "juju" {}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "nfs-group" {
  name     = "nfs-group"
  location = "East US"
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
  name = "charmed-hpc"

  cloud {
    name   = "azure"
    region = "eastus"
  }

  config = {
    resource-group-name = azurerm_resource_group.nfs-group.name
    network             = azurerm_virtual_network.nfs-vnet.name
    # Needed to work around azure storage pool requests hanging. MySQL deployment gets stuck at
    # "agent initialising" otherwise.
    storage-default-filesystem-source = "rootfs"
  }
}

module "nfs-share" {
  source = "git::https://github.com/charmed-hpc/charmed-hpc-terraform//modules/azure-managed-nfs"

  name                = "nfs-share"
  resource_group_name = azurerm_resource_group.nfs-group.name
  subnet_info = {
    name                 = azurerm_subnet.nfs-subnet.name
    virtual_network_name = azurerm_subnet.nfs-subnet.virtual_network_name
  }
  model_name = juju_model.charmed-hpc.name
  quota      = 100
  mountpoint = "/nfs/home"
  depends_on = [
    azurerm_resource_group.nfs-group
  ]
}

## MySQL - provides backing database for the accounting node.
module "mysql" {
  source = "git::https://github.com/canonical/mysql-operator//terraform"

  juju_model_name = juju_model.charmed-hpc.name
  app_name        = "mysql"
  channel         = "8.0/stable"
  units           = 1
}

module "slurm" {
  source = "git::https://github.com/charmed-hpc/charmed-hpc-terraform//modules/slurm"

  model_name = juju_model.charmed-hpc.name
  database_backend = {
    name     = module.mysql.application_name,
    endpoint = module.mysql.provides.database
  }

  # Optional settings for the controller node.
  controller = {
    app_name = "slurmctld"
  }

  # Optional settings for the database node.
  database = {
    app_name = "slurmdbd"
  }

  # Optional settings for the REST API node.
  rest_api = {
    app_name = "slurmrestd"
  }

  # Optional settings for the kiosk node.
  kiosk = {
    app_name = "login",
    units    = 1,
  }

  # Compute partitions to be deployed.
  compute_partitions = {
    "hb120rs-v3" : {
      constraints = "arch=amd64 instance-type=Standard_HB120rs_v3",
      units       = 2,
    },
    "nc4as-t4-v3" : {
      constraints = "arch=amd64 instance-type=Standard_NC4as_T4_v3",
      units       = 1,
    }
  }
  depends_on = [
    juju_model.charmed-hpc
  ]
}

# Since the filesystem client is a subordinate charm, it uses
# the `juju-info` endpoint to integrate with other charms.
resource "juju_integration" "login-to-filesystem-client" {
  model = juju_model.charmed-hpc.name

  application {
    name     = module.slurm.kiosk.app_name
    endpoint = "juju-info"
  }

  application {
    name     = module.nfs-share.app_name
    endpoint = "juju-info"
  }
}

resource "juju_integration" "compute-to-filesystem-client" {
  model    = juju_model.charmed-hpc.name
  for_each = module.slurm.compute_partitions

  application {
    name     = each.key
    endpoint = "juju-info"
  }

  application {
    name     = module.nfs-share.app_name
    endpoint = "juju-info"
  }
}
