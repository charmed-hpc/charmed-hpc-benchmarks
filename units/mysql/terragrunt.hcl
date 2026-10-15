# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

include "root" {
  path = find_in_parent_folders("units/root.hcl")
}

terraform {
  source = "git::https://github.com/canonical/mysql-operators//machines/terraform?ref=c357f39dbbed80b2ae123766d68a5201d0b7f15a"
}
