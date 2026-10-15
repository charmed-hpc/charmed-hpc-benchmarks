# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

output "kiosk" {
  description = "Deployed kiosk (login) application."
  value       = module.slurm.kiosk
}

output "compute_partitions" {
  description = "Deployed compute partitions, keyed by application name."
  value       = module.slurm.compute_partitions
}
