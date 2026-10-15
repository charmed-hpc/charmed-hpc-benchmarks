# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

variable "model_name" {
  description = "Name of the Juju model to deploy the cluster into."
  type        = string
  default     = "charmed-hpc"
  nullable    = false
}

variable "region" {
  description = "Azure region to deploy the cluster into."
  type        = string
  default     = "eastus"
  nullable    = false
}

variable "location" {
  description = "Azure location (display name) for the resource group."
  type        = string
  default     = "East US"
  nullable    = false
}

variable "resource_group_name" {
  description = "Name of the Azure resource group to create for the cluster network and NFS share."
  type        = string
  default     = "nfs-group"
  nullable    = false
}
