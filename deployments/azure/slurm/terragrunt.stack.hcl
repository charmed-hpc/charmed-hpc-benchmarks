# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

stack "slurm" {
  source = "${get_path_to_repo_root()}/stacks/slurm"
  path   = "slurm"

  values = {
    compute_partitions = {
      "hb120rs-v3" : {
        constraints = "arch=amd64 instance-type=Standard_HB120rs_v3"
        units       = 2
      }
      "nc4as-t4-v3" : {
        constraints = "arch=amd64 instance-type=Standard_NC4as_T4_v3"
        units       = 1
      }
    }
  }
}
