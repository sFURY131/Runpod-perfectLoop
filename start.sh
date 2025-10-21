#!/usr/bin/env bash
set -euo pipefail

echo "[*] Boot sequence started…"

: "${COMFY_BRANCH:=master}"
: "${COMFY_PATH:=/ComfyUI}"
: "${COMFY_PORT:=8188}"

: "${WORKFLOW_JSON_URL:=}"
: "${WORKFLOW_JSON_PATH:=/workflows/flow.json}"

: "${CHECKPOINT_URLS:=}"
: "${VAE_URLS:=}"
: "${LORA_URLS:=}"

: "${CIVITAI_TOKEN:=}"
: "${CHECKPOINT_VERSION_IDS:=}"
: "${VAE_VERSION_IDS:=}"
: "${LORA_VERSION_IDS:=}"

: "${CUSTOM_NODE_REPOS:=}"

if [ ! -d "${COMFY_PATH}/.git" ]; then
  echo "[*] Cloning ComfyUI → ${COMFY_PATH}"
  git clone --branch "${COMFY_BRANCH}" https://github.com/comfyanonymous/ComfyUI.git "${COMFY_PATH}"
else
  echo "[*] Updating ComfyUI at ${COMFY_PATH}"
  git -C "${COMFY_PATH}" fetch --all || true
  git -C "${COMFY_PATH}" checkout "${COMFY_BRANCH}" || true
  git -C "${COMFY_PATH}" pull || true
fi

if [ ! -d "${COMFY_PATH}/venv" ]; then
  echo "[*] Creating venv"
  python3 -m venv "${COMFY_PATH}/venv"
fi
source "${COMFY_PATH}/venv/bin/activate"
pip install --upgrade pip wheel
pip install -r "${COMFY_PATH}/requirements.txt" || true
pip install opencv-python-headless requests

if [ -n "${CUSTOM_NODE_REPOS}" ]; then
  IFS=',' read -ra REPOS <<< "${CUSTOM_NODE_REPOS}"
  for repo in "${REPOS[@]}"; do
    name="$(basename "${repo%.*}")"
    dest="${COMFY_PATH}/custom_nodes/${name}"
    if [ ! -d "${dest}/.git" ]; then
      echo "[*] Installing custom node: ${repo}"
      git clone "${repo}" "${dest}" || true
    else
      git -C "${dest}" pull || true
    fi
  done
fi

if [ -n "${WORKFLOW_JSON_URL}" ]; then
  echo "[*] Downloading workflow JSON → ${WORKFLOW_JSON_PATH}"
  mkdir -p "$(dirname "${WORKFLOW_JSON_PATH}")"
  aria2c -q --allow-overwrite=true -o "$(basename "${WORKFLOW_JSON_PATH}")" -d "$(dirname "${WORKFLOW_JSON_PATH}")" "${WORKFLOW_JSON_URL}" || true
fi

/opt/download_models.sh \
  --checkpoints-urls "${CHECKPOINT_URLS}" \
  --vae-urls "${VAE_URLS}" \
  --lora-urls "${LORA_URLS}" \
  --checkpoint-ids "${CHECKPOINT_VERSION_IDS}" \
  --vae-ids "${VAE_VERSION_IDS}" \
  --lora-ids "${LORA_VERSION_IDS}" \
  --civitai-token "${CIVITAI_TOKEN}"

echo "[*] Launching ComfyUI on 0.0.0.0:${COMFY_PORT}"
exec python3 "${COMFY_PATH}/main.py" --listen 0.0.0.0 --port "${COMFY_PORT}"
