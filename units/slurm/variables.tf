# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

variable "model_uuid" {
  description = "UUID of the Juju model to deploy the cluster into."
  type        = string
  nullable    = false
}

variable "database_backend" {
  description = <<-EOT
    Database backend for the Slurm accounting node (slurmdbd): the MySQL
    application name and its `database` provides endpoint.
  EOT
  type = object({
    name     = string
    endpoint = string
  })
  nullable = false
}

variable "controller" {
  description = "Settings for the slurmctld controller node."
  type = object({
    app_name    = optional(string, "slurmctld")
    config      = optional(map(string))
    constraints = optional(string)
  })
  default  = {}
  nullable = false
}

variable "compute_partitions" {
  description = "Compute partitions to deploy, keyed by application name."
  type = map(object({
    constraints = optional(string)
    units       = optional(number, 1)
  }))
  default = {
    "default" : {
      units = 1,
    }
  }
  nullable = false
}

variable "kiosk" {
  description = "Settings for the kiosk (login) node."
  type = object({
    app_name = optional(string, "login")
    units    = optional(number, 1)
  })
  default  = {}
  nullable = false
}

variable "filesystem_client" {
  description = <<-EOT
    Filesystem client application to integrate with the kiosk and compute
    nodes over `juju-info`. All deployments require a shared filesystem.
  EOT
  type = object({
    app_name = string
  })
  nullable = false
}
