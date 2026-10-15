# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

include "root" {
  path = find_in_parent_folders("units/root.hcl")
}

terraform {
  source = "git::https://github.com/canonical/charmed-hpc-terraform//modules/controller?ref=e585d13f4a82289f6bfcd20c39f178bc5db6b30c"
}

# The module declares the juju provider but does not configure it; bootstrap
# requires controller mode.
generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "juju" {
      controller_mode = true
    }
  EOF
}

inputs = {
  name           = "charmed-hpc"
  bootstrap_base = "ubuntu@24.04"

  cloud = {
    name       = "azure"
    type       = "azure"
    auth_types = ["service-principal-secret"]

    region = {
      name = "eastus"
    }
  }

  cloud_credential = {
    name      = "azure-sp"
    auth_type = "service-principal-secret"
    attributes = {
      "application-id"       = get_env("ARM_CLIENT_ID", "")
      "subscription-id"      = get_env("ARM_SUBSCRIPTION_ID", "")
      "application-password" = get_env("ARM_CLIENT_SECRET", "")
    }
  }

  bootstrap_constraints = {
    "instance-type" = "Standard_D4s_v3"
    "arch"          = "amd64"
  }
}
