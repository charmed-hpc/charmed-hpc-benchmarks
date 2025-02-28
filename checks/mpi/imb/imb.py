# Copyright 2025 Canonical Ltd.
# See LICENSE file for licensing details.

"""Intel MPI Benchmarks (IMB) checks."""

import os

import reframe as rfm
import reframe.utility.sanity as sn

REFERENCE = {
    "azure:hb120rs-v3": {
        "pingpong_bw": (22784, -0.15, 0.2, "MB/s"),
        "allreduce_latency": (1.9, -0.25, 0.1, "us"),
    },
}


class build_imb(rfm.CompileOnlyRegressionTest):
    """Build Intel MPI benchmarks source code."""

    descr = "Build Intel MPI Benchmarks"
    sourcesdir = "https://github.com/intel/mpi-benchmarks.git"
    version = variable(str, value="71ebc45e90c394b0229977a27a40a05b480fedbe")
    prebuild_cmds = [f"git checkout {version}"]
    build_system = "Make"

    @run_before("compile")
    def prepare_build(self):
        """Add build system options."""
        self.build_system.options = ["IMB-MPI1"]


class imb_base_check(rfm.RunOnlyRegressionTest):
    """Base class for Intel MPI benchmarks checks."""

    valid_systems = ["*"]
    valid_prog_environs = ["+mpi"]
    imb_binary = fixture(build_imb, scope="environment")
    reference = REFERENCE

    # Job directives
    num_tasks = 2
    num_tasks_per_node = 1
    num_cpus_per_task = 1
    time_limit = "10m"

    @run_before("run")
    def set_executable(self):
        """Set job script commands."""
        self.executable = os.path.join(self.imb_binary.stagedir, "IMB-MPI1")

    @sanity_function
    def validate(self):
        """Validate output."""
        return sn.assert_found(r"Intel", self.stdout)


@rfm.simple_test
class imb_pingpong_check(imb_base_check):
    """Intel MPI benchmarks point-to-point checks."""

    descr = "IMB1 PingPong check"
    executable_opts = ["PingPong"]

    @performance_function("MB/s")
    def pingpong_bw(self):
        """Extract bandwidth from output.

        Example output:
            #bytes  #repetitions      t[usec]   Mbytes/sec
            4194304           10       178.82     23455.12

         Returns 23455.12.
        """
        return sn.extractsingle(r"^\s+4194304\s+(\S+)\s+(\S+)\s+(\S+)", self.stdout, 3, float)


@rfm.simple_test
class imb_allreduce_check(imb_base_check):
    """Intel MPI benchmarks collective checks."""

    descr = "IMB1 AllReduce check"
    executable_opts = ["AllReduce"]

    @performance_function("us")
    def allreduce_latency(self):
        """Extract average latency from output.

        Example output:
            #bytes #repetitions  t_min[usec]  t_max[usec]  t_avg[usec]
                 8         1000         0.53         3.29         1.91

         Returns 1.91.
        """
        return sn.extractsingle(r"\s+8\s+1000\s+(\S+)\s+(\S+)\s+(\S+)", self.stdout, 3, float)
