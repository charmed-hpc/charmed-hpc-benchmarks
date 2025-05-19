# Copyright 2025 Canonical Ltd.
# See LICENSE file for licensing details.

"""Checks for Slurm REST API health."""

import reframe as rfm
import reframe.utility.sanity as sn

REFERENCE = {
    "azure:login": {"real_time": (0.1, None, 0.1, "s")},
}


@rfm.simple_test
class slurmrestd_api_check(rfm.RunOnlyRegressionTest):
    """Slurm REST API health check."""

    valid_systems = ["*:login"]
    valid_prog_environs = ["builtin"]
    reference = REFERENCE

    slurmrestd_hostname = variable(str, value="localhost")
    # v0.0.40 is current as of slurm-wlm 23.11.4.
    slurmrestd_api_version = variable(str, value="v0.0.40")

    @run_before("run")
    def set_run_commands(self):
        """Set job script commands."""
        # Generate a JWT token for Slurm API access (default life 30 mins).
        # This is exported as environment variable $SLURM_JWT.
        # Unset any existing $SLURM_JWT as this being set to an expired or invalid token may prevent
        # the scontrol call to request a new token from succeeding.
        self.prerun_cmds = ["unset SLURM_JWT; export $(scontrol token)"]

        # Job script uses `curl` to run API diagnostics from all valid_systems. Latency is measured
        # using `time`.
        self.executable = "time"
        self.executable_opts = [
            "-p",
            "curl",
            "-s",
            "-H X-SLURM-USER-TOKEN:$SLURM_JWT",
            f"-X GET 'http://{self.slurmrestd_hostname}:6820/slurm/{self.slurmrestd_api_version}/diag'",
        ]

    @sanity_function
    def validate(self):
        """Validate output."""
        return sn.all(
            [sn.assert_eq(self.job.exitcode, 0), sn.assert_found(r'"errors": \[\]', self.stdout)]
        )

    @performance_function("s")
    def real_time(self):
        """Extract runtime in seconds."""
        return sn.extractsingle(r"real (?P<real_time>\S+)", self.stderr, "real_time", float)
