# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

module "slurm" {
  source = "git::https://github.com/canonical/charmed-hpc-terraform//modules/slurm?ref=e585d13f4a82289f6bfcd20c39f178bc5db6b30c"

  model_uuid       = var.model_uuid
  database_backend = var.database_backend

  # Optional settings for the controller node.
  controller = var.controller

  # Optional settings for the database node.
  database = {
    app_name = "slurmdbd"
  }

  # Optional settings for the REST API node.
  rest_api = {
    app_name = "slurmrestd"
  }

  # Optional settings for the kiosk node.
  kiosk = var.kiosk

  # Compute partitions to be deployed.
  compute_partitions = var.compute_partitions
}

# Since the filesystem client is a subordinate charm, it uses
# the `juju-info` endpoint to integrate with other charms.
resource "juju_integration" "kiosk-to-filesystem-client" {
  model_uuid = var.model_uuid

  application {
    name     = module.slurm.kiosk.app_name
    endpoint = "juju-info"
  }

  application {
    name     = var.filesystem_client.app_name
    endpoint = "juju-info"
  }
}

resource "juju_integration" "compute-to-filesystem-client" {
  for_each   = module.slurm.compute_partitions
  model_uuid = var.model_uuid

  application {
    name     = each.key
    endpoint = "juju-info"
  }

  application {
    name     = var.filesystem_client.app_name
    endpoint = "juju-info"
  }
}
