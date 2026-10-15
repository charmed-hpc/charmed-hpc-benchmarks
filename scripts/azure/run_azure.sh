#!/bin/bash
# Copyright 2025 Canonical Ltd.
# See LICENSE file for licensing details.
set -euo pipefail

MODEL=charmed-hpc
REPO_ROOT="$(git rev-parse --show-toplevel)"
# Terragrunt stack that bootstraps the controller and deploys the cluster.
STACK_DIR="${REPO_ROOT}/deployments/azure/slurm"

# Validate environment before running
for var in ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_SUBSCRIPTION_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: environment variable ${var} is not set."
    echo "Export ARM_CLIENT_ID, ARM_CLIENT_SECRET and ARM_SUBSCRIPTION_ID before launching this script."
    exit 1
  fi
done

echo "Started at `date`"

# echo "Bootstrapping azure controller and deploying cluster..."
terragrunt stack run apply --non-interactive --working-dir "${STACK_DIR}"

# Set up temporary Juju CLI access to the bootstrapped controller. The
# setup command only exports JUJU_DATA (the `juju login` part is dropped);
# the login is done separately with the admin password piped to stdin so it
# doesn't prompt.
eval $(terragrunt stack output -raw slurm.controller.juju_cli_setup_command \
  --working-dir "${STACK_DIR}" | cut -d'&' -f1)
CONTROLLER_NAME=charmed-hpc
# `-raw` output has no trailing newline, but `juju login` reads a line from
# stdin — echo appends one, otherwise the read hits EOF and the controller
# drops the connection ("cannot get discharge ... EOF").
echo "$(terragrunt stack output -raw slurm.controller.connection.password \
  --working-dir "${STACK_DIR}")" \
  | juju login -c "${CONTROLLER_NAME}" -u admin --trust --no-prompt

# wait-for command below fails to return when model reaches desired state and eventually times out:
#   juju wait-for model charmed-hpc --query='forEach(applications, app => app.status == "active")'
# HACK Work around by manually polling juju status
juju switch "${CONTROLLER_NAME}:admin/${MODEL}"
while true; do
  echo "Waiting for all model applications to become active..."
  all_active=$(juju status --format=json | jq -r '[.applications | to_entries[] | .value["application-status"].current == "active"] | all')
  [[ "$all_active" == "false" ]] || break
  sleep 20
done
SLURMRESTD_HOST=$(juju status slurmrestd --format json | jq -r '.machines[.applications.slurmrestd.units | to_entries[] | .value.machine].hostname')

# Workaround for "juju ssh" giving "Permission denied (publickey)" by default.
# Using random tmpfile name to avoid filename collision. Assuming no file will be created at the
# returned path between the mktemp and ssh-keygen calls so -u can safely be used.
mkdir -p "$HOME/tmp/$MODEL"
SSH_KEY_PATH="$(mktemp -p $HOME/tmp/"$MODEL"/ -u)"
echo "Generating new key pair at ${SSH_KEY_PATH}..."
ssh-keygen -t ed25519 -f "${SSH_KEY_PATH}" -N ""
juju add-ssh-key "$(cat ${SSH_KEY_PATH}.pub)"

# Mark all compute nodes as idle. Node names are derived from the unit names
# (e.g. hb120rs-v3/0 -> hb120rs-v3-0), since the numbering is inconsistent
# and a fixed range would fail on unknown node names.
for app in hb120rs-v3 nc4as-t4-v3; do
  nodes=$(juju status "$app" --format=json \
    | jq -r --arg app "$app" '.applications[$app].units | keys[] | sub("/"; "-")' \
    | paste -sd, -)
  juju run slurmctld/leader set-node-state nodes="$nodes" state=idle
done

# Needed for gpu_burn test
echo "Installing libcublas12 package on GPU node"
juju ssh nc4as-t4-v3/leader -i "${SSH_KEY_PATH}" <<"EOF"
sudo apt-get update
sudo apt-get install -y libcublas12
EOF

echo  "Installing and running ReFrame suite on the login node..."
# Push the current state of this repo (including uncommitted changes) to the
# login node instead of cloning from GitHub, so local edits to the checks are
# tested. `git ls-files` respects .gitignore; any stale copy is removed first.
# The archive is piped over ssh stdin (juju scp proved unreliable here).
git -C "${REPO_ROOT}" ls-files -z --exclude-standard -c -o \
  | tar -C "${REPO_ROOT}" --null --files-from=- --create --file=- --ignore-failed-read \
  | juju ssh login/leader -i "${SSH_KEY_PATH}" -- "cat > /nfs/home/charmed-hpc-benchmarks.tar"

juju ssh login/leader -i "${SSH_KEY_PATH}" -- bash -s "${SLURMRESTD_HOST}" <<"EOF"
set -euo pipefail
# Software necessary for building ReFrame test applications
sudo apt-get update
sudo apt-get -y install libopenmpi-dev build-essential python3-venv nvidia-cuda-toolkit-gcc

# Use shared file system for all tests
cd /nfs/home

# Refresh the checks with the archive copied from the local machine
rm -rf charmed-hpc-benchmarks
mkdir charmed-hpc-benchmarks
tar -xf charmed-hpc-benchmarks.tar -C charmed-hpc-benchmarks
rm charmed-hpc-benchmarks.tar

# Install ReFrame and suite. The hpctestlib modules used by the checks are
# vendored into the repo (lib/hpctestlib) since ReFrame 4.10 no longer ships
# them in the PyPI package.
python3 -m venv reframe-venv
source reframe-venv/bin/activate
pip install ReFrame-HPC
cd charmed-hpc-benchmarks

# hpctestlib modules used by the checks are vendored in lib/ (ReFrame does not
# add check directories to sys.path)
export PYTHONPATH="/nfs/home/charmed-hpc-benchmarks/lib:${PYTHONPATH:-}"

# Recursively run all checks
reframe --config-file config/azure_config.py --checkpath checks --recursive --run --setvar slurmrestd_api_check.slurmrestd_hostname="$1"
EOF

echo  "Copying back test outputs..."
juju scp -- -i "${SSH_KEY_PATH}" -r login/leader:/nfs/home/charmed-hpc-benchmarks/perflogs .
juju scp -- -i "${SSH_KEY_PATH}" -r login/leader:/nfs/home/charmed-hpc-benchmarks/output .

echo "Destroying cluster and controller..."
# Retry destroy command on failure. Can happen if a VM is still using nfs-vnet when attempt to
# destroy it occurs. TODO: confirm if race condition/bug in Juju provider.
retries=0
max_retries=5
retry_timer=60
while ! terragrunt stack run destroy --non-interactive --working-dir "${STACK_DIR}" && [ $retries -lt $max_retries ]; do
    retries=$((retries+1))
    echo "Attempt $retries failed. Retrying in $retry_timer seconds..."
    sleep $retry_timer
done

echo "Deleting temporary SSH key pair at: ${SSH_KEY_PATH}..."
rm -f "${SSH_KEY_PATH}" "${SSH_KEY_PATH}.pub"

echo "Tests completed at `date`. Check output and perflogs directories for results."
