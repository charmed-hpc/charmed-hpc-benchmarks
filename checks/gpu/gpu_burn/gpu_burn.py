# Copyright 2025 Canonical Ltd.
# See LICENSE file for licensing details.

"""gpu-burn checks."""

import os

import reframe as rfm
from hpctestlib.microbenchmarks.gpu.gpu_burn import gpu_burn_build, gpu_burn_check

REFERENCE = {
    "single": {
        "azure:nc4as-t4-v3": {
            "gpu_perf_min": (4100, -0.10, 0.25, "Gflop/s"),
        },
    },
    "double": {
        "azure:nc4as-t4-v3": {
            "gpu_perf_min": (250, -0.10, 0.25, "Gflop/s"),
        },
    },
}


class charmed_gpu_burn_build(gpu_burn_build):
    """Build gpu-burn source code."""

    # HACK to work around gpu_burn source (erroneously) not being included in the ReFrame PyPi
    # package, as of v4.7.3. Include source with this test and use absolute path as relative path
    # is relative to `site-packages/hpctestlib/`.
    dir_path = os.path.dirname(os.path.realpath(__file__))
    sourcesdir = os.path.join(dir_path, "src/gpu_burn")


class charmed_gpu_burn_check_base(gpu_burn_check):
    """Base class for gpu-burn checks."""

    valid_systems = ["*"]
    valid_prog_environs = ["+cuda"]
    gpu_burn_binaries = fixture(charmed_gpu_burn_build, scope="environment")
    duration = 60


@rfm.simple_test
class charmed_gpu_burn_check_single(charmed_gpu_burn_check_base):
    """Single precision gpu-burn check."""

    use_dp = False
    reference = REFERENCE["single"]


@rfm.simple_test
class charmed_gpu_burn_check_double(charmed_gpu_burn_check_base):
    """Double precision gpu-burn check."""

    use_dp = True
    reference = REFERENCE["double"]
