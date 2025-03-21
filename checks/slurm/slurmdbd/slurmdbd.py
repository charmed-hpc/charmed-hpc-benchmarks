# Copyright 2025 Canonical Ltd.
# See LICENSE file for licensing details.

"""Checks for Slurm accounting database health."""


import reframe as rfm
import reframe.utility.sanity as sn

REFERENCE = {
    "azure:login": {"real_time": (0.2, None, 0.1, "s")},
}


@rfm.simple_test
class slurmrmdbd_check(rfm.RunOnlyRegressionTest):
    """Slurm accounting database health check."""

    valid_systems = ["*:login"]
    valid_prog_environs = ["builtin"]
    reference = REFERENCE

    @run_before("run")
    def set_run_commands(self):
        """Set job script commands."""
        # Use `sacct` to check responsiveness of accounting database from all valid_systems.
        # Latency is measured using `time`.
        self.executable = "time"
        self.executable_opts = [
            "-p",
            "sacct",
            "--starttime=now-10minutes",
        ]

    @sanity_function
    def validate(self):
        """Validate output."""
        return sn.all([sn.assert_eq(self.job.exitcode, 0), sn.assert_found(r"JobID", self.stdout)])

    @performance_function("s")
    def real_time(self):
        """Extract runtime in seconds."""
        return sn.extractsingle(r"real (?P<real_time>\S+)", self.stderr, "real_time", float)
