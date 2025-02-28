# Copyright 2025 Canonical Ltd.
# See LICENSE file for licensing details.

"""Microsoft Azure site configuration."""

site_configuration = {
    "systems": [
        {
            "name": "azure",
            "descr": "Microsoft Azure test deployment cluster",
            "hostnames": ["juju"],
            "modules_system": "nomod",
            "partitions": [
                {
                    "name": "login",
                    "descr": "Cluster login nodes",
                    "launcher": "local",
                    "environs": ["builtin"],
                    "scheduler": "local",
                },
                {
                    "name": "hb120rs-v3",
                    "descr": "Standard_HB120rs_v3 instances - RDMA-enabled partition",
                    "launcher": "mpirun",
                    "environs": ["builtin", "mpi-gnu"],
                    "access": ["--partition=hb120rs-v3"],
                    "scheduler": "slurm",
                    "time_limit": "1h",
                    "max_jobs": 100,
                },
                {
                    "name": "nc4as-t4-v3",
                    "descr": "Standard_NC4as_T4_v3 instances - Tesla T4 GPU-equipped partition",
                    "launcher": "local",
                    "environs": ["builtin", "cuda"],
                    "access": ["--partition=nc4as-t4-v3", "--gres=gpu:1"],
                    "scheduler": "slurm",
                    "time_limit": "1h",
                    "max_jobs": 100,
                },
            ],
        },
    ],  # end of systems
    "environments": [
        {
            "name": "cuda",
            "cc": "nvcc",
            "cxx": "nvcc",
            "target_systems": ["azure"],
            "features": ["cuda"],
        },
        {
            "name": "mpi-gnu",
            "cc": "mpicc",
            "cxx": "mpicxx",
            "ftn": "mpif90",
            "target_systems": ["azure"],
            "features": ["mpi"],
        },
        {
            "name": "builtin",
            "cc": "cc",
            "cxx": "CC",
            "ftn": "ftn",
            "target_systems": ["azure"],
        },
    ],  # end of environments
}
