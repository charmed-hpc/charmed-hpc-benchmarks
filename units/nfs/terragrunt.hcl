# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

# Deploy the NFS share on the network scaffolding provisioned by the network
# unit. Outputs the filesystem client app name for the slurm unit. The
# dependencies and provider configuration are declared by the parent stack's
# autoinclude (see `stacks/slurm/terragrunt.stack.hcl`), keeping this unit
# generic.

include "root" {
  path = find_in_parent_folders("units/root.hcl")
}

terraform {
  source = "git::https://github.com/canonical/charmed-hpc-terraform//modules/nfs/azure?ref=e585d13f4a82289f6bfcd20c39f178bc5db6b30c"
}
