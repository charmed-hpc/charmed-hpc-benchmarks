# Vendored from https://github.com/reframe-hpc/reframe (v4.10.3).
#
# hpctestlib is no longer included in the ReFrame PyPI package as of v4.10.0
# (hatchling build config only packages `reframe`), so the modules used by the
# checks here are vendored directly. This directory lives outside `checks/` on
# purpose: ReFrame treats every RegressionTest subclass it scans as a test,
# which would pick up hpctestlib's undecorated base classes. It is made
# importable via PYTHONPATH (see scripts/azure/run_azure.sh). When adding
# more, only vendor what is needed and keep upstream files unmodified so they
# can be updated in place from a newer ReFrame tag.
