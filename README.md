# Charmed HPC Benchmarks

ReFrame tests for benchmarking and validating a Charmed HPC cluster deployment on Microsoft Azure.

Description of directories:

* [`checks`](./checks): the test cases.
* [`config`](./config): the site configuration, including cluster partitions and programming
environments.
* [`scripts`](./scripts): scripts for automatically deploying a cluster, running the test suite,
and retrieving the results.

## ✨ Getting started

A Charmed HPC deployment on Microsoft Azure is required with:

* Single instances of `slurmctld`, `slurmdbd`, and `sackd`.
* At least one instance of `slurmd` as application `nc4as-t4-v3` deployed on a VM of size `Standard_NC4as_T4_v3`.
* At least two instances of `slurmd` as application `hb120rs-v3` deployed on VMs of size `Standard_HB120rs_v3`.
* A shared NFS file system mounted on all `slurmd` and `sackd` instances at `/nfs/home`.

Example configuration:

```shell
Model        Controller       Cloud/Region  Version  SLA          Timestamp
charmed-hpc  test-controller  azure/eastus  3.6.3    unsupported  11:57:49Z

App               Version          Status  Scale  Charm              Channel      Rev  Exposed  Message
hb120rs-v3        23.11.4-1.2u...  active      2  slurmd             latest/edge  115  no
login             23.11.4-1.2u...  active      1  sackd              latest/edge   12  no
mysql             8.0.39-0ubun...  active      1  mysql              8.0/stable   313  no
nc4as-t4-v3       23.11.4-1.2u...  active      1  slurmd             latest/edge  115  no
nfs-share-client                   active      4  filesystem-client  latest/edge   15  no       Mounted filesystem at `/nfs/home`.
nfs-share-server                   active      1  nfs-server-proxy   latest/edge   21  no
slurmctld         23.11.4-1.2u...  active      1  slurmctld          latest/edge   94  no
slurmdbd          23.11.4-1.2u...  active      1  slurmdbd           latest/edge   86  no
slurmrestd        23.11.4-1.2u...  active      1  slurmrestd         latest/edge   88  no

Unit                   Workload  Agent  Machine  Public address   Ports           Message
hb120rs-v3/0*          active    idle   3        x.x.x.x
  nfs-share-client/1   active    idle            x.x.x.x                          Mounted filesystem at `/nfs/home`.
hb120rs-v3/1           active    idle   4        x.x.x.x
  nfs-share-client/2   active    idle            x.x.x.x                          Mounted filesystem at `/nfs/home`.
login/0*               active    idle   0        x.x.x.x
  nfs-share-client/0*  active    idle            x.x.x.x                          Mounted filesystem at `/nfs/home`.
mysql/1*               active    idle   6        x.x.x.x          3306,33060/tcp  Primary
nc4as-t4-v3/1*         active    idle   5        x.x.x.x
  nfs-share-client/3   active    idle            x.x.x.x                          Mounted filesystem at `/nfs/home`.
nfs-share-server/0*    active    idle   8        x.x.x.x
slurmctld/0*           active    idle   1        x.x.x.x
slurmdbd/1*            active    idle   7        x.x.x.x
slurmrestd/0*          active    idle   2        x.x.x.x

Machine  State    Address          Inst id        Base          AZ  Message
0        started  x.x.x.x          juju-50c1e0-0  ubuntu@24.04
1        started  x.x.x.x          juju-50c1e0-1  ubuntu@24.04
2        started  x.x.x.x          juju-50c1e0-2  ubuntu@24.04
3        started  x.x.x.x          juju-50c1e0-3  ubuntu@24.04
4        started  x.x.x.x          juju-50c1e0-4  ubuntu@24.04
5        started  x.x.x.x          juju-50c1e0-5  ubuntu@24.04
6        started  x.x.x.x          juju-50c1e0-6  ubuntu@22.04
7        started  x.x.x.x          juju-50c1e0-7  ubuntu@24.04
8        started  x.x.x.x          juju-50c1e0-8  ubuntu@24.04
```

The test suite should be launched from a `sackd` instance, i.e. a login node. Prerequisites can be
installed by connecting to the login node and running:

```shell
sudo apt install libopenmpi-dev build-essential python3-venv nvidia-cuda-toolkit-gcc
python3 -m venv reframe-venv
source reframe-venv/bin/activate
pip install Reframe-HPC
```

Additionally, all `nc4as-t4-v3` instances should have the following prerequisites installed to
enable execution of the GPU tests:

```shell
sudo apt install libcublas12
```

The suite can then be launched from the login node with:

```shell
git clone https://github.com/charmed-hpc/charmed-hpc-benchmarks
cd charmed-hpc-benchmarks
reframe -C config/azure_config.py -c checks -r -R
```

## 🤔 What's next?

To learn more about the benchmarks and Charmed HPC in general, the following resources are available:

* [Charmed HPC Documentation](https://canonical-charmed-hpc.readthedocs-hosted.com/en/latest)
* [Documentation in `scripts` subdirectories for supported clouds](./scripts)
* [Open an issue](https://github.com/charmed-hpc/charmed-hpc-benchmarks/issues/new?title=ISSUE+TITLE&body=*Please+describe+your+issue*)
* [Ask a question on the Charmed HPC GitHub](https://github.com/orgs/charmed-hpc/discussions/categories/q-a)

## 🛠️ Development

Useful commands to help while hacking on the checks are:

```shell
tox run -e fmt # Apply formatting standards to code.
tox run -e lint # Check code against coding style standards.
```

If you're interested in contributing, take a look at our [contributing guidelines](./CONTRIBUTING.md).

## 🤝 Project and community

The Charmed HPC Benchmarks are a project of the [Ubuntu High-Performance Computing community](https://ubuntu.com/community/governance/teams/hpc). Interested in contributing bug fixes, patches, documentation, or feedback? Want to join the Ubuntu HPC community? You’ve come to the right place!

Here’s some links to help you get started with joining the community:

* [Ubuntu Code of Conduct](https://ubuntu.com/community/ethos/code-of-conduct)
* [Contributing guidelines](./CONTRIBUTING.md)
* [Join the conversation on Matrix](https://matrix.to/#/#hpc:ubuntu.com)
* [Get the latest news on Discourse](https://discourse.ubuntu.com/c/hpc/151)
* [Ask and answer questions on GitHub](https://github.com/orgs/charmed-hpc/discussions/categories/q-a)

## 📋 License

The Charmed HPC Benchmarks are free software, distributed under the Apache Software License, version 2.0.
See the [Apache-2.0 LICENSE](./LICENSE) file for further details.

The accompanying gpu-burn source code is free software, distributed under the BSD 2-Clause License.
