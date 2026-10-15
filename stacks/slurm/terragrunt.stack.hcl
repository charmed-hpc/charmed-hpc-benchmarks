# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

locals {
  controller         = try(values.controller, {})
  kiosk              = try(values.kiosk, {})
  compute_partitions = try(values.compute_partitions, {})
}

unit "controller" {
  source = "${get_path_to_repo_root()}/units/controller"
  path   = "controller"
}

# Azure network scaffolding: resource group, network, subnet, and the Juju
# model.
unit "network" {
  source = "${get_path_to_repo_root()}/units/network"
  path   = "network"

  autoinclude {
    dependency "controller" {
      config_path = unit.controller.path

      # Mock outputs let init/validate/plan succeed before the controller
      # unit has been applied.
      mock_outputs = {
        connection = {
          controller_addresses = "localhost:17070"
          username             = "admin"
          password             = "changeme"
          ca_certificate       = "changeme"
        }
      }
      mock_outputs_allowed_terraform_commands = ["init", "validate"]
    }

    generate "providers" {
      path      = "providers.tf"
      if_exists = "overwrite_terragrunt"
      contents  = <<-EOF
        provider "juju" {
          controller_addresses = "${dependency.controller.outputs.connection.controller_addresses}"
          username             = "${dependency.controller.outputs.connection.username}"
          password             = "${dependency.controller.outputs.connection.password}"
          ca_certificate       = <<CERT
${dependency.controller.outputs.connection.ca_certificate}
CERT
          skip_failed_deletion = true
        }

        provider "azurerm" {
          features {}
        }
      EOF
    }
  }
}

# NFS share on the network scaffolding provisioned by the network unit.
unit "nfs" {
  source = "${get_path_to_repo_root()}/units/nfs"
  path   = "nfs"

  autoinclude {
    dependency "controller" {
      config_path = unit.controller.path

      # Mock outputs let init/validate/plan succeed before the controller
      # unit has been applied.
      mock_outputs = {
        connection = {
          controller_addresses = "localhost:17070"
          username             = "admin"
          password             = "changeme"
          ca_certificate       = "changeme"
        }
      }
      mock_outputs_allowed_terraform_commands = ["init", "validate"]
    }

    dependency "network" {
      config_path = unit.network.path

      mock_outputs = {
        model_uuid          = "00000000-0000-0000-0000-000000000000"
        resource_group_name = "nfs-group"
        subnet_info = {
          name                 = "nfs-subnet"
          virtual_network_name = "nfs-vnet"
        }
      }
      mock_outputs_allowed_terraform_commands = ["init", "validate"]
    }

    generate "providers" {
      path      = "providers.tf"
      if_exists = "overwrite_terragrunt"
      contents  = <<-EOF
        provider "juju" {
          controller_addresses = "${dependency.controller.outputs.connection.controller_addresses}"
          username             = "${dependency.controller.outputs.connection.username}"
          password             = "${dependency.controller.outputs.connection.password}"
          ca_certificate       = <<CERT
${dependency.controller.outputs.connection.ca_certificate}
CERT
          skip_failed_deletion = true
        }

        provider "azurerm" {
          features {}
        }
      EOF
    }

    inputs = {
      model_uuid          = dependency.network.outputs.model_uuid
      resource_group_name = dependency.network.outputs.resource_group_name
      subnet_info         = dependency.network.outputs.subnet_info
      name                = "nfs-share"
      quota               = 100
      mountpoint          = "/nfs/home"
    }
  }
}

# MySQL database backing the Slurm accounting node.
unit "mysql" {
  source = "${get_path_to_repo_root()}/units/mysql"
  path   = "mysql"

  autoinclude {
    dependency "controller" {
      config_path = unit.controller.path

      # Mock outputs let init/validate/plan succeed before the controller
      # unit has been applied.
      mock_outputs = {
        connection = {
          controller_addresses = "localhost:17070"
          username             = "admin"
          password             = "changeme"
          ca_certificate       = "changeme"
        }
      }
      mock_outputs_allowed_terraform_commands = ["init", "validate"]
    }

    dependency "network" {
      config_path = unit.network.path

      mock_outputs = {
        model_uuid = "00000000-0000-0000-0000-000000000000"
      }
      mock_outputs_allowed_terraform_commands = ["init", "validate"]
    }

    generate "providers" {
      path      = "providers.tf"
      if_exists = "overwrite_terragrunt"
      contents  = <<-EOF
        provider "juju" {
          controller_addresses = "${dependency.controller.outputs.connection.controller_addresses}"
          username             = "${dependency.controller.outputs.connection.username}"
          password             = "${dependency.controller.outputs.connection.password}"
          ca_certificate       = <<CERT
${dependency.controller.outputs.connection.ca_certificate}
CERT
          skip_failed_deletion = true
        }

        provider "azurerm" {
          features {}
        }
      EOF
    }

    inputs = {
      model    = dependency.network.outputs.model_uuid
      app_name = "mysql"
      channel  = "8.4/candidate"
      units    = 1
    }
  }
}

# The Slurm cluster itself, deployed on the infrastructure provisioned by the
# units above.
unit "slurm" {
  source = "${get_path_to_repo_root()}/units/slurm"
  path   = "slurm"

  autoinclude {
    dependency "controller" {
      config_path = unit.controller.path

      # Mock outputs let init/validate/plan succeed before the controller
      # unit has been applied.
      mock_outputs = {
        connection = {
          controller_addresses = "localhost:17070"
          username             = "admin"
          password             = "changeme"
          ca_certificate       = "changeme"
        }
      }
      mock_outputs_allowed_terraform_commands = ["init", "validate"]
    }

    dependency "network" {
      config_path = unit.network.path

      mock_outputs = {
        model_uuid = "00000000-0000-0000-0000-000000000000"
      }
      mock_outputs_allowed_terraform_commands = ["init", "validate"]
    }

    dependency "nfs" {
      config_path = unit.nfs.path

      mock_outputs = {
        app_name = "nfs-share"
      }
      mock_outputs_allowed_terraform_commands = ["init", "validate"]
    }

    dependency "mysql" {
      config_path = unit.mysql.path

      mock_outputs = {
        app_name = "mysql"
        provides = {
          database = "database"
        }
      }
      mock_outputs_allowed_terraform_commands = ["init", "validate"]
    }

    generate "providers" {
      path      = "providers.tf"
      if_exists = "overwrite_terragrunt"
      contents  = <<-EOF
        provider "juju" {
          controller_addresses = "${dependency.controller.outputs.connection.controller_addresses}"
          username             = "${dependency.controller.outputs.connection.username}"
          password             = "${dependency.controller.outputs.connection.password}"
          ca_certificate       = <<CERT
${dependency.controller.outputs.connection.ca_certificate}
CERT
          skip_failed_deletion = true
        }

        provider "azurerm" {
          features {}
        }
      EOF
    }

    inputs = {
      model_uuid        = dependency.network.outputs.model_uuid
      filesystem_client = { app_name = dependency.nfs.outputs.app_name }
      database_backend = {
        name     = dependency.mysql.outputs.app_name
        endpoint = dependency.mysql.outputs.provides.database
      }

      controller         = local.controller
      kiosk              = local.kiosk
      compute_partitions = local.compute_partitions
    }
  }
}
