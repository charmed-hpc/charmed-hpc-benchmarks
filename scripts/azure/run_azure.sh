#!/bin/bash
# Copyright 2025 Canonical Ltd.
# See LICENSE file for licensing details.
set -e

MODEL=charmed-hpc
CONTROLLER=test-controller

# Validate environment before running
if [ -z "${ARM_SUBSCRIPTION_ID}" ]; then
  echo "ERROR: environment variable ARM_SUBSCRIPTION_ID is not set."
  echo "Run \`export ARM_SUBSCRIPTION_ID=<your-azure-subscription-id>\` before launching this script."
  exit 1
fi

echo "Started at `date`"

echo "Bootstrapping azure controller: ${CONTROLLER}..."
juju bootstrap azure $CONTROLLER --constraints "instance-role=auto"

echo "Deploying plan to set up cluster..."
tofu init
tofu apply -auto-approve

# wait-for command below fails to return when model reaches desired state and eventually times out:
#   juju wait-for model charmed-hpc --query='forEach(applications, app => app.status == "active")'
# HACK Work around by manually polling juju status
juju switch ${MODEL}
while true; do
  echo "Waiting for all model applications to become active..."
  all_active=$(juju status --format=json | jq -r '[.applications | to_entries[] | .value["application-status"].current == "active"] | all')
  [[ "$all_active" == "false" ]] || break
  sleep 5
done

# Workaround for "juju ssh" giving "Permission denied (publickey)" by default.
# Using random tmpfile name to avoid filename collision. Assuming no file will be created at the
# returned path between the mktemp and ssh-keygen calls so -u can safely be used.
SSH_KEY_PATH="$(mktemp -p $HOME/.ssh/ -u)"
echo "Generating new key pair at ${SSH_KEY_PATH}..."
ssh-keygen -t ed25519 -f "${SSH_KEY_PATH}" -N ""
juju add-ssh-key "$(cat ${SSH_KEY_PATH}.pub)"

juju run nc4as-t4-v3/leader node-configured
sleep 8 # HACK for node-configured action being racy
# Can't just run on hb120rs-v3/0 and hb120rs-v3/1 as numbering is inconsistent. Could be
# hb120rs-v3/2 and hb120rs-v3/3.
for unit in $(juju status hb120rs-v3 --format=json | jq -r '.applications."hb120rs-v3".units | keys[]'); do
  juju run $unit node-configured
  sleep 8
done

# Needed for gpu_burn test
echo "Installing libcublas12 package on GPU node"
juju ssh nc4as-t4-v3/leader -i "${SSH_KEY_PATH}" << "EOF"
sudo apt-get update
sudo apt-get install -y libcublas12
EOF

echo  "Installing and running ReFrame suite on the login node..."
juju ssh login/leader -i "${SSH_KEY_PATH}" << "EOF"
# Software necessary for building ReFrame test applications
sudo apt-get update
sudo apt-get -y install libopenmpi-dev build-essential python3-venv nvidia-cuda-toolkit-gcc

# Use shared file system for all tests
cd /nfs/home

# Install ReFrame and suite
python3 -m venv reframe-venv
source reframe-venv/bin/activate
pip install ReFrame-HPC
git clone https://github.com/charmed-hpc/charmed-hpc-benchmarks.git
cd charmed-hpc-benchmarks

# Recursively run all checks
reframe -C config/azure_config.py -c checks -r -R

logout
EOF

echo  "Copying back test outputs..."
juju scp -- -i "${SSH_KEY_PATH}" -r login/leader:/nfs/home/charmed-hpc-benchmarks/perflogs .
juju scp -- -i "${SSH_KEY_PATH}" -r login/leader:/nfs/home/charmed-hpc-benchmarks/output .

echo "Destroying cluster..."
# Retry destroy command on failure. Can happen if a VM is still using nfs-vnet when attempt to
# destroy it occurs. TODO: confirm if race condition/bug in Juju provider.
retries=0
max_retries=2
while ! tofu destroy -auto-approve && [ $retries -lt $max_retries ]; do
    retries=$((retries+1))
    echo "Attempt $retries failed. Retrying in 10 seconds..."
    sleep 10
done

echo "Destroying controller: ${CONTROLLER}..."
juju destroy-controller ${CONTROLLER} --force --no-prompt --destroy-all-models --destroy-storage
echo "Deleting temporary SSH key pair at: ${SSH_KEY_PATH}..."
rm -f "${SSH_KEY_PATH}" "${SSH_KEY_PATH}.pub"

echo "Tests completed at `date`. Check output and perflogs directories for results."
