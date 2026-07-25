#!/usr/bin/env bash
# deploy_nodezero_host.sh
# Recreates the nodezero-host GCE VM + Docker + h3-cli + NodeZero Runner service.
# Usage: H3_API_KEY="<runner-api-key>" ./deploy_nodezero_host.sh

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-horizon3-hack26sfo-3706}"
ZONE="${ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-nodezero-host}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-standard-4}"
NETWORK="${NETWORK:-default}"
NETWORK_TAG="${NETWORK_TAG:-h3-fleet}"
BOOT_DISK_SIZE="${BOOT_DISK_SIZE:-128GB}"
IMAGE_FAMILY="${IMAGE_FAMILY:-ubuntu-2204-lts}"
IMAGE_PROJECT="${IMAGE_PROJECT:-ubuntu-os-cloud}"

: "${H3_API_KEY:?Set H3_API_KEY to your NodeZero Runner API key before running}"

gcloud config set project "${PROJECT_ID}"

# --- 1. Create the VM ---
gcloud compute instances create "${VM_NAME}" \
  --zone="${ZONE}" \
  --machine-type="${MACHINE_TYPE}" \
  --network="${NETWORK}" \
  --image-family="${IMAGE_FAMILY}" \
  --image-project="${IMAGE_PROJECT}" \
  --boot-disk-size="${BOOT_DISK_SIZE}" \
  --boot-disk-type=pd-balanced \
  --tags="${NETWORK_TAG}"

# Wait for SSH to become available
until gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --command="echo ready" &>/dev/null; do
  echo "Waiting for SSH..."; sleep 5
done

# --- 2. Install Docker ---
gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --command='
set -e
sudo apt-get update -y
sudo apt-get install -y docker.io unzip curl
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker "$(whoami)"
docker --version
'

# --- 3. Install h3-cli ---
gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --command='
set -e
cd ~
curl -L https://downloads.horizon3ai.com/utilities/cli/h3-cli.zip -o h3-cli.zip
unzip -o h3-cli.zip -d h3-cli
'

# --- 4. Configure h3-cli with the Runner API key ---
gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --command="
set -e
cd ~/h3-cli
bash install.sh '${H3_API_KEY}'
"

# --- 5. Register the NodeZero Runner as a systemd service ---
gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --command="
export H3_CLI_HOME=\$HOME/h3-cli
export PATH=\"\$H3_CLI_HOME/bin:\$PATH\"
sudo -E env \"H3_CLI_HOME=\$H3_CLI_HOME\" \"PATH=\$PATH\" h3 start-runner-service '${VM_NAME}'
"

echo "Done. Verify with:"
echo "  gcloud compute ssh ${VM_NAME} --zone=${ZONE} --command='sudo systemctl status nodezero-runner-${VM_NAME}'"
