# Azure Benchmarking Script

To allow for easier use of the benchmarks, the `run_azure.sh` script and accompanying Terragrunt stack automatically deploy a cluster, run the full test suite, and retrieve the results.

The deployment is an [explicit Terragrunt stack](https://docs.terragrunt.com/features/stacks/explicit/): `deployments/azure/slurm/terragrunt.stack.hcl` instantiates the reusable stack in `stacks/slurm` with the cluster configuration the benchmarks require. The stack composes four units defined in the top-level `units/` directory:

* `units/controller/`: bootstraps a Juju controller on Azure (`eastus`) using the `modules/controller` module from [`canonical/charmed-hpc-terraform`](https://github.com/canonical/charmed-hpc-terraform).
* `units/network/`: provisions the Azure network scaffolding (resource group, virtual network, subnet, security group, Juju model) using the `modules/azure/network` module.
* `units/nfs/`: deploys the NFS share using the `modules/nfs/azure` module from `canonical/charmed-hpc-terraform`, reading the model UUID, resource group, and subnet from the `network` unit.
* `units/slurm/`: deploys the Slurm cluster using the cloud-agnostic `modules/slurm` module, reading the Juju connection from `controller`, the model UUID from `network`, and the filesystem client app name from `nfs`.

Running `terragrunt stack generate` (or any `terragrunt stack run` command) in `deployments/azure/slurm` materializes the units into `deployments/azure/slurm/.terragrunt-stack`.

The deployed cluster contains:

* Single instances of `slurmctld`, `slurmdbd`, and `sackd`.
* One instance of `slurmd` as application `nc4as-t4-v3` deployed on a VM of size `Standard_NC4as_T4_v3`.
* Two instances of `slurmd` as application `hb120rs-v3` deployed on VMs of size `Standard_HB120rs_v3`.
* A shared NFS file system mounted on all `slurmd` and `sackd` instances at `/nfs/home`.

A temporary SSH key pair is created at `~/.ssh/tmp.<string>` and `~/.ssh/tmp.<string>.pub`, then used for `juju ssh` remote access to `slurmd` and `sackd` instances to install software and launch the benchmarks. Benchmark results are copied back from the `sackd` instance to the local machine via `juju scp`.

The temporary key pair is deleted when the script ends. The cluster deployment is torn down and the bootstrapped Juju controller destroyed.

After completion, benchmark results are located in the `output` and `perflogs` directories relative to the script.

## Prerequisites

Before running the script, you will need:

* A [Microsoft Azure subscription ID](https://learn.microsoft.com/en-us/azure/azure-portal/get-subscription-tenant-id) with access to compute resources.
* A Microsoft Entra service principal registered as a Juju credential for the `azure` cloud (i.e. you have run `juju add-credential azure` with an application ID, subscription ID, and application password). No controller needs to be bootstrapped beforehand; the stack bootstraps one automatically.
* [Azure quota](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests) for [at least one `Standard_NC4as_T4_v3` VM and at least two `Standard_HB120rs_v3` VMs](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/overview).
* The following installed on your machine:
  * [Juju CLI client](https://juju.is/docs/juju/install-and-manage-the-client)
  * [OpenTofu infrastructure as code tool](https://opentofu.org/docs/intro/install/)
  * [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/)
  * [`jq` command-line JSON processor](https://jqlang.org/)

The units take their Azure configuration from the standard `ARM_*` environment variables:

| Variable | Description |
| --- | --- |
| `ARM_CLIENT_ID` | Service principal application ID |
| `ARM_CLIENT_SECRET` | Service principal application secret |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID |

The values should already be in your registered Juju credential. To export them automatically (requires `yq`):

```shell
cred=$(juju show-credentials azure --show-secrets --format yaml)
export ARM_CLIENT_ID=$(echo "$cred" | yq -r '.["client-credentials"].azure.*.details.application-id')
export ARM_CLIENT_SECRET=$(echo "$cred" | yq -r '.["client-credentials"].azure.*.details.application-password')
export ARM_SUBSCRIPTION_ID=$(echo "$cred" | yq -r '.["client-credentials"].azure.*.details.subscription-id')
```

## Running

The script can be executed by cloning this repository then:

```shell
export ARM_CLIENT_ID=<your_application_id>
export ARM_CLIENT_SECRET=<your_application_password>
export ARM_SUBSCRIPTION_ID=<your_azure_subscription_id>
cd charmed-hpc-benchmarks/scripts/azure/
./run_azure.sh
```

## Adjusting the deployment

The cluster is deployed from the reusable units at `stacks`. The Slurm cluster configuration (`controller`, `kiosk`, `compute_partitions`) is exposed as stack values by `stacks/slurm/terragrunt.stack.hcl`; adjust the values set in `deployments/azure/slurm/terragrunt.stack.hcl`, or instantiate the stack from another `terragrunt.stack.hcl` and override them via `values`:

```hcl
stack "slurm" {
  source = "git::https://github.com/charmed-hpc/charmed-hpc-benchmarks//stacks/slurm?ref=<rev>"
  path   = "slurm"

  values = {
    compute_partitions = {
      "hb120rs-v3" : {
        constraints = "arch=amd64 instance-type=Standard_HB120rs_v3"
        units       = 4
      }
    }
  }
}
```

Infrastructure-level values (`model_name`, `region`, `location`, `resource_group_name`; see `modules/azure/network/variables.tf`) are not set in the units' `inputs`, so they can still be overridden without modifying the Terragrunt configuration by exporting `TF_VAR_*` environment variables before running the script. Terragrunt forwards them to the modules.

## Clean-up

The script automatically cleans up all resources on exit. If it is interrupted, manual clean-up can be performed by:

* Destroying the stack **(DATA LOSS WARNING)**: `terragrunt stack run destroy --non-interactive --working-dir deployments/azure/slurm`
* Deleting the temporary SSH key pair at `~/.ssh/tmp.<string>` and `~/.ssh/tmp.<string>.pub`
* [Deleting remnant resource groups on Azure](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/delete-resource-group?tabs=azure-portal) **(DATA LOSS WARNING)**: `nfs-group` and `juju-controller-<string>`
