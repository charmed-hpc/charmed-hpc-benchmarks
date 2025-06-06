# Azure Benchmarking Script

To allow for easier use of the benchmarks, the `run_azure.sh` script and accompanying `main.tf` plan automatically deploy a cluster, run the full test suite, and retrieve the results.

First, a Juju controller is bootstrapped for Azure, followed by application of the `main.tf` plan to deploy a cluster containing:

* Single instances of `slurmctld`, `slurmdbd`, and `sackd`.
* One instance of `slurmd` as application `nc4as-t4-v3` deployed on a VM of size `Standard_NC4as_T4_v3`.
* Two instances of `slurmd` as application `hb120rs-v3` deployed on VMs of size `Standard_HB120rs_v3`.
* A shared NFS file system mounted on all `slurmd` and `sackd` instances at `/nfs/home`.

A temporary SSH key pair is created at `~/.ssh/tmp.<string>` and `~/.ssh/tmp.<string>.pub`, then used for `juju ssh` remote access to `slurmd` and `sackd` instances to install software and launch the benchmarks. Benchmark results are copied back from the `sackd` instance to the local machine via `juju scp`.

The temporary key pair is deleted when the script ends. The cluster deployment is torn down and the bootstrapped Juju controller destroyed.

After completion, benchmark results are located in the `output` and `perflogs` directories relative to the script.

## Prerequisites

Before running the script, you will need:

* A [Microsoft Azure subscription ID](https://learn.microsoft.com/en-us/azure/azure-portal/get-subscription-tenant-id) with access to compute resources, exported as environment variable `ARM_SUBSCRIPTION_ID`
* [Azure quota](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests) for [at least one `Standard_NC4as_T4_v3` VM and at least two `Standard_HB120rs_v3` VMs](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/overview).
* The following installed on your machine:
  * [Juju CLI client](https://juju.is/docs/juju/install-and-manage-the-client)
  * [OpenTofu infrastructure as code tool](https://opentofu.org/docs/intro/install/)
  * [`jq` command-line JSON processor](https://jqlang.org/)
* [Your Azure credentials added to the Juju CLI client](https://canonical-charmed-hpc.readthedocs-hosted.com/latest/howto/initialize-cloud-environment/) but no controller bootstrapped

## Running

The script can be executed by cloning this repository then:

```shell
export ARM_SUBSCRIPTION_ID=<your_azure_id>
cd charmed-hpc-benchmarks/scripts/azure/
./run_azure.sh
```

A sample run follows:

```shell
$ git clone https://github.com/charmed-hpc/charmed-hpc-benchmarks
Cloning into 'charmed-hpc-benchmarks'...
remote: Enumerating objects: 52, done.
remote: Counting objects: 100% (52/52), done.
remote: Compressing objects: 100% (38/38), done.
remote: Total 52 (delta 2), reused 52 (delta 2), pack-reused 0 (from 0)
Receiving objects: 100% (52/52), 32.79 KiB | 1.73 MiB/s, done.
Resolving deltas: 100% (2/2), done.
$ export ARM_SUBSCRIPTION_ID=xxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxxx
$ cd charmed-hpc-benchmarks/scripts/azure/
$ ./run_azure.sh
Started at Fri Mar 14 01:23:51 PM GMT 2025
Bootstrapping azure controller: test-controller...
Creating Juju controller "test-controller" on azure/eastus
[...]
Bootstrap complete, controller "test-controller" is now available
[...]
Deploying plan to set up cluster...
[...]
Plan: 31 to add, 0 to change, 0 to destroy.
[...]
Apply complete! Resources: 31 added, 0 changed, 0 destroyed.
test-controller:admin/charmed-hpc (no change)
Waiting for all model applications to become active...
[...]
Generating new key pair at /home/me/.ssh/tmp.LBlf8B1RH1...
Generating public/private ed25519 key pair.
[...]
Installing libcublas12 package on GPU node
[...]
Installing and running ReFrame suite on the login node...
[...]
[ReFrame Setup]
  version:           4.7.4
  command:           '/nfs/home/reframe-venv/bin/reframe -C config/azure_config.py -c checks -r -R'
  launched by:       ubuntu@juju-11f797-0
  working directory: '/nfs/home/charmed-hpc-benchmarks'
  settings files:    '<builtin>', 'config/azure_config.py'
  selected system:   'azure'
  check search path: (R) '/nfs/home/charmed-hpc-benchmarks/checks'
  stage directory:   '/nfs/home/charmed-hpc-benchmarks/stage'
  output directory:  '/nfs/home/charmed-hpc-benchmarks/output'
  log files:         '/tmp/rfm-1mqldfzz.log'
  results database:  '/home/ubuntu/.reframe/reports/results.db'

[==========] Running 19 check(s)
[==========] Started on Fri Mar 14 13:44:40 2025+0000

[----------] start processing checks
[ RUN      ] fetch_osu_benchmarks ~azure /52eaa96b @azure:hb120rs-v3+mpi-gnu
[ RUN      ] build_imb ~azure:hb120rs-v3+mpi-gnu /6291d54f @azure:hb120rs-v3+mpi-gnu
[ RUN      ] build_fio ~azure:login+builtin /64f4f23f @azure:login+builtin
[ RUN      ] build_fio ~azure:hb120rs-v3+builtin /d323208d @azure:hb120rs-v3+builtin
[ RUN      ] build_fio ~azure:nc4as-t4-v3+builtin /bdf3b13c @azure:nc4as-t4-v3+builtin
[ RUN      ] charmed_gpu_burn_build ~azure:nc4as-t4-v3+cuda /b8cce080 @azure:nc4as-t4-v3+cuda
[       OK ] ( 1/27) fetch_osu_benchmarks ~azure /52eaa96b @azure:hb120rs-v3+mpi-gnu
[ RUN      ] charmed_build_osu %build_type=cpu ~azure:hb120rs-v3+mpi-gnu /be611a6f @azure:hb120rs-v3+mpi-gnu
[       OK ] ( 2/27) build_imb ~azure:hb120rs-v3+mpi-gnu /6291d54f @azure:hb120rs-v3+mpi-gnu
[ RUN      ] imb_allreduce_check /89fb35f3 @azure:hb120rs-v3+mpi-gnu
[ RUN      ] imb_pingpong_check /02be03af @azure:hb120rs-v3+mpi-gnu
[       OK ] ( 3/27) imb_allreduce_check /89fb35f3 @azure:hb120rs-v3+mpi-gnu
P: allreduce_latency: 1.72 us (r:1.9, l:-0.25, u:0.1)
[       OK ] ( 4/27) charmed_gpu_burn_build ~azure:nc4as-t4-v3+cuda /b8cce080 @azure:nc4as-t4-v3+cuda
[ RUN      ] charmed_gpu_burn_check_double /482318a4 @azure:nc4as-t4-v3+cuda
[ RUN      ] charmed_gpu_burn_check_single /fd2f7e4e @azure:nc4as-t4-v3+cuda
[       OK ] ( 5/27) imb_pingpong_check /02be03af @azure:hb120rs-v3+mpi-gnu
P: pingpong_bw: 23471.73 MB/s (r:22784, l:-0.15, u:0.2)
[       OK ] ( 6/27) charmed_build_osu %build_type=cpu ~azure:hb120rs-v3+mpi-gnu /be611a6f @azure:hb120rs-v3+mpi-gnu
[ RUN      ] charmed_osu_collective_check %benchmark_info=('mpi.collective.osu_allreduce', 'latency') %osu_binaries.build_type=cpu /6ab1f3e8 @azure:hb120rs-v3+mpi-gnu
[ RUN      ] charmed_osu_collective_check %benchmark_info=('mpi.collective.osu_alltoall', 'latency') %osu_binaries.build_type=cpu /0f58ee29 @azure:hb120rs-v3+mpi-gnu
[ RUN      ] charmed_osu_pt2pt_check %benchmark_info=('mpi.pt2pt.osu_latency', 'latency') %osu_binaries.build_type=cpu /d79530cf @azure:hb120rs-v3+mpi-gnu
[ RUN      ] charmed_osu_pt2pt_check %benchmark_info=('mpi.pt2pt.osu_bw', 'bandwidth') %osu_binaries.build_type=cpu /1bd7abf4 @azure:hb120rs-v3+mpi-gnu
[       OK ] ( 7/27) charmed_osu_collective_check %benchmark_info=('mpi.collective.osu_allreduce', 'latency') %osu_binaries.build_type=cpu /6ab1f3e8 @azure:hb120rs-v3+mpi-gnu
P: latency: 1.74 us (r:1.9, l:-0.25, u:0.1)
[       OK ] ( 8/27) charmed_osu_collective_check %benchmark_info=('mpi.collective.osu_alltoall', 'latency') %osu_binaries.build_type=cpu /0f58ee29 @azure:hb120rs-v3+mpi-gnu
P: latency: 1.71 us (r:1.9, l:-0.25, u:0.1)
[       OK ] ( 9/27) charmed_osu_pt2pt_check %benchmark_info=('mpi.pt2pt.osu_latency', 'latency') %osu_binaries.build_type=cpu /d79530cf @azure:hb120rs-v3+mpi-gnu
P: latency: 1.63 us (r:1.9, l:-0.25, u:0.1)
[       OK ] (10/27) build_fio ~azure:login+builtin /64f4f23f @azure:login+builtin
[ RUN      ] fio_check_nfs %mode=write /ed465ebe @azure:login+builtin
[ RUN      ] fio_check_nfs %mode=read /ad24c956 @azure:login+builtin
[ RUN      ] fio_check_home %mode=write /b9da0cd4 @azure:login+builtin
[ RUN      ] fio_check_home %mode=read /660fcbd3 @azure:login+builtin
[       OK ] (11/27) charmed_gpu_burn_check_double /482318a4 @azure:nc4as-t4-v3+cuda
P: gpu_perf_min: 250.0 Gflop/s (r:250, l:-0.1, u:0.25)
P: gpu_temp_max: 46.0 degC (r:0, l:None, u:None)
[       OK ] (12/27) fio_check_home %mode=write /b9da0cd4 @azure:login+builtin
P: extract_bandwidth: 19.126953125 MiB/s (r:0, l:None, u:None)
P: extract_iops: 4.781829 IOPS (r:0, l:None, u:None)
[       OK ] (13/27) fio_check_nfs %mode=write /ed465ebe @azure:login+builtin
P: extract_bandwidth: 100.828125 MiB/s (r:0, l:None, u:None)
P: extract_iops: 25.207162 IOPS (r:0, l:None, u:None)
[       OK ] (14/27) fio_check_nfs %mode=read /ad24c956 @azure:login+builtin
P: extract_bandwidth: 41.44140625 MiB/s (r:0, l:None, u:None)
P: extract_iops: 10.360465 IOPS (r:0, l:None, u:None)
[       OK ] (15/27) build_fio ~azure:hb120rs-v3+builtin /d323208d @azure:hb120rs-v3+builtin
[ RUN      ] fio_check_nfs %mode=write /ed465ebe @azure:hb120rs-v3+builtin
[ RUN      ] fio_check_nfs %mode=read /ad24c956 @azure:hb120rs-v3+builtin
[ RUN      ] fio_check_home %mode=write /b9da0cd4 @azure:hb120rs-v3+builtin
[ RUN      ] fio_check_home %mode=read /660fcbd3 @azure:hb120rs-v3+builtin
[       OK ] (16/27) charmed_osu_pt2pt_check %benchmark_info=('mpi.pt2pt.osu_bw', 'bandwidth') %osu_binaries.build_type=cpu /1bd7abf4 @azure:hb120rs-v3+mpi-gnu
P: bandwidth: 24505.48 MB/s (r:22784, l:-0.15, u:0.2)
[       OK ] (17/27) build_fio ~azure:nc4as-t4-v3+builtin /bdf3b13c @azure:nc4as-t4-v3+builtin
[ RUN      ] fio_check_nfs %mode=write /ed465ebe @azure:nc4as-t4-v3+builtin
[ RUN      ] fio_check_nfs %mode=read /ad24c956 @azure:nc4as-t4-v3+builtin
[ RUN      ] fio_check_home %mode=write /b9da0cd4 @azure:nc4as-t4-v3+builtin
[ RUN      ] fio_check_home %mode=read /660fcbd3 @azure:nc4as-t4-v3+builtin
[       OK ] (18/27) fio_check_home %mode=read /660fcbd3 @azure:login+builtin
P: extract_bandwidth: 201.8623046875 MiB/s (r:0, l:None, u:None)
P: extract_iops: 50.465724 IOPS (r:0, l:None, u:None)
[       OK ] (19/27) charmed_gpu_burn_check_single /fd2f7e4e @azure:nc4as-t4-v3+cuda
P: gpu_perf_min: 4454.0 Gflop/s (r:4100, l:-0.1, u:0.25)
P: gpu_temp_max: 49.0 degC (r:0, l:None, u:None)
[       OK ] (20/27) fio_check_nfs %mode=write /ed465ebe @azure:hb120rs-v3+builtin
P: extract_bandwidth: 80.4248046875 MiB/s (r:0, l:None, u:None)
P: extract_iops: 20.106259 IOPS (r:0, l:None, u:None)
[       OK ] (21/27) fio_check_home %mode=write /b9da0cd4 @azure:hb120rs-v3+builtin
P: extract_bandwidth: 2542.51953125 MiB/s (r:0, l:None, u:None)
P: extract_iops: 635.630043 IOPS (r:0, l:None, u:None)
[       OK ] (22/27) fio_check_nfs %mode=read /ad24c956 @azure:hb120rs-v3+builtin
P: extract_bandwidth: 36.7236328125 MiB/s (r:0, l:None, u:None)
P: extract_iops: 9.181002 IOPS (r:0, l:None, u:None)
[       OK ] (23/27) fio_check_nfs %mode=write /ed465ebe @azure:nc4as-t4-v3+builtin
P: extract_bandwidth: 22.9033203125 MiB/s (r:0, l:None, u:None)
P: extract_iops: 5.725855 IOPS (r:0, l:None, u:None)
[       OK ] (24/27) fio_check_nfs %mode=read /ad24c956 @azure:nc4as-t4-v3+builtin
P: extract_bandwidth: 77.7802734375 MiB/s (r:0, l:None, u:None)
P: extract_iops: 19.445277 IOPS (r:0, l:None, u:None)
[       OK ] (25/27) fio_check_home %mode=write /b9da0cd4 @azure:nc4as-t4-v3+builtin
P: extract_bandwidth: 65.0947265625 MiB/s (r:0, l:None, u:None)
P: extract_iops: 16.273739 IOPS (r:0, l:None, u:None)
[       OK ] (26/27) fio_check_home %mode=read /660fcbd3 @azure:hb120rs-v3+builtin
P: extract_bandwidth: 3324.6748046875 MiB/s (r:0, l:None, u:None)
P: extract_iops: 831.168831 IOPS (r:0, l:None, u:None)
[       OK ] (27/27) fio_check_home %mode=read /660fcbd3 @azure:nc4as-t4-v3+builtin
P: extract_bandwidth: 66.0224609375 MiB/s (r:0, l:None, u:None)
P: extract_iops: 16.505824 IOPS (r:0, l:None, u:None)
[----------] all spawned checks have finished

[  PASSED  ] Ran 27/27 test case(s) from 19 check(s) (0 failure(s), 0 skipped, 0 aborted)
[==========] Finished on Fri Mar 14 13:52:37 2025+0000
Log file(s) saved in '/tmp/rfm-1mqldfzz.log'
Copying back test outputs...
Destroying cluster...
[...]
Destroy complete! Resources: 31 destroyed.
Destroying controller: test-controller...
[...]
Deleting temporary SSH key pair at: /home/me/.ssh/tmp.LBlf8B1RH1...
Tests completed at Fri Mar 14 02:00:48 PM GMT 2025. Check output and perflogs directories for results.
```

## Clean-up

The script automatically cleans up all resources on exit. If it is interrupted, manual clean-up can be performed by:

* Destroying the Juju controller and models **(DATA LOSS WARNING)**: `juju destroy-controller test-controller --force --destroy-all-models --destroy-storage`
* Deleting the temporary SSH key pair at `~/.ssh/tmp.<string>` and `~/.ssh/tmp.<string>.pub`
* [Deleting remnant resource groups on Azure](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/delete-resource-group?tabs=azure-portal) **(DATA LOSS WARNING)**: `nfs-group` and `juju-controller-<string>`
