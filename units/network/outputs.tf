# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

output "model_uuid" {
  description = "UUID of the Juju model the cluster was deployed into."
  value       = juju_model.charmed-hpc.uuid
}

output "resource_group_name" {
  description = "Name of the Azure resource group the cluster network was deployed into."
  value       = azurerm_resource_group.nfs-group.name
}

output "subnet_info" {
  description = "Information about the subnet the NFS share is allocated on."
  value = {
    name                 = azurerm_subnet.nfs-subnet.name
    virtual_network_name = azurerm_subnet.nfs-subnet.virtual_network_name
  }
}
