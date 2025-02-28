# Copyright 2025 Canonical Ltd.
# See LICENSE file for licensing details.

"""Ohio State University (OSU) MPI checks."""

import reframe as rfm
from hpctestlib.microbenchmarks.mpi.osu import (
    build_osu_benchmarks,
    osu_build_run,
)

REFERENCE = {
    "azure:hb120rs-v3": {
        "bandwidth": (22784, -0.15, 0.2, "MB/s"),
        "latency": (1.9, -0.25, 0.1, "us"),
    },
}


class charmed_build_osu(build_osu_benchmarks):
    """Build OSU source code."""

    build_type = parameter(["cpu"])


class charmed_osu_check(osu_build_run):
    """Base class for OSU checks."""

    valid_systems = ["*"]
    valid_prog_environs = ["+mpi"]
    osu_binaries = fixture(charmed_build_osu, scope="environment")
    reference = REFERENCE


@rfm.simple_test
class charmed_osu_pt2pt_check(charmed_osu_check):
    """OSU MPI point-to-point checks."""

    benchmark_info = parameter(
        [
            ("mpi.pt2pt.osu_bw", "bandwidth"),
            ("mpi.pt2pt.osu_latency", "latency"),
        ]
    )


@rfm.simple_test
class charmed_osu_collective_check(charmed_osu_check):
    """OSU MPI collective checks."""

    num_tasks = 2
    benchmark_info = parameter(
        [
            ("mpi.collective.osu_alltoall", "latency"),
            ("mpi.collective.osu_allreduce", "latency"),
        ]
    )
