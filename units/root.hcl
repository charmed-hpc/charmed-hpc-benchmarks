# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

# Shared Terragrunt configuration for the units: local state stored outside
# the generated `.terragrunt-stack` directories, so it survives
# `terragrunt stack clean && terragrunt stack generate`.

remote_state {
  backend = "local"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    path = "${get_repo_root()}/.terragrunt-local-state/${get_path_from_repo_root()}/tofu.tfstate"
  }
}
