# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

include "root" {
  path = find_in_parent_folders("units/root.hcl")
}

terraform {
  source = "."
}
