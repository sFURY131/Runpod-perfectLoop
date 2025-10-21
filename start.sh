#!/usr/bin/env bash
set -euo pipefail

echo "[*] Boot sequence started…"

# -------- ENV (defaults; you can override in RunPod UI) --------
: "${COMFY_BRANCH:=master}"
: "${COMFY_PATH:=/ComfyUI}"
: "${COMFY_PORT:=8188}"

# JupyterLab
: "${JUPYTER_PORT:=8888}"         # <- expose this port in template (HTTP Ports)
# Optional: set a fixed token by uncommenting the next line and adding to env vars
# : "${JUPYTER_TOKEN:=}"          # leave empty to let Jupyter auto-generate a token

# Workflow JSON
: "${WORKFLOW_JSON_URL:=}"
: "${WORKFLOW_JSON_PATH:=/workflows/flow.json}"

# Model inputs (keep what you already had)
: "${CHECKPOINT_URLS:=}"
: "${VAE_URLS:=}"
: "${LORA_URLS:=}"
: "${CIVITAI_TOKEN:=}"
: "${CHECKPOINT_VERSION_IDS:=}"
: "${VAE_VERSION_IDS:=}"
: "${LORA_VERSION_IDS:=}"

# Optional extra groups you may already be using
: "${DIFFUSION_MODEL_URLS:=}"
: "${TEXT_ENCODER_URLS:=}"
: "${FRAME_INTERP_URLS:=}"
: "${CUSTOM_NODE_REPOS:=}"

# ---------------------------------------------------------------

# 1) Clone / update ComfyUI
if [ ! -d "${COMFY_PATH}/.git" ]; then
  echo "[*] Cloning ComfyUI → ${COMFY_PATH}"
  git clone --branch "${COMFY_BRANCH}" https://github.com/comfyanonymous/ComfyUI.git "${COMFY_PATH}"
else
  echo "[*] Updating ComfyUI at ${COMFY_PATH}"
  git -C "${COMFY_PATH}" fetch --all || true
  git -C "${COMFY_PATH}" checkout "${COMFY_BRANCH}" || true
  git -C "${COMFY_PATH}" pull || true
fi

# 2) Python venv + deps
if [ ! -d "${COMFY_PATH}/venv" ]; then
  echo "[*] Creating venv"
  python3 -m venv "${COMFY_PATH}/venv"
fi
source "${COMFY_PATH}/venv/bin/activate"
pip install --upgrade pip wheel

echo "[*] Installing PyTorch for CUDA 12.8…"
pip install --index-url https://download.pytorch.org/whl/cu128 \
  torch torchvision torchaudio

echo "[*] Installing ComfyUI + dependencies…"
pip install -r "${COMFY_PATH}/requirements.txt" || true
pip install opencv-python-headless requests jupyterlab

# --- NEW: Install JupyterLab into the same venv ---
pip install jupyterlab

# 3) Custom nodes (if any)
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

# 4) Download workflow JSON
if [ -n "${WORKFLOW_JSON_URL}" ]; then
  echo "[*] Downloading workflow JSON → ${WORKFLOW_JSON_PATH}"
  mkdir -p "$(dirname "${WORKFLOW_JSON_PATH}")"
  aria2c -q --allow-overwrite=true -o "$(basename "${WORKFLOW_JSON_PATH}")" -d "$(dirname "${WORKFLOW_JSON_PATH}")" "${WORKFLOW_JSON_URL}" || true
fi

# 5) Download models (keep your current script/args)
#    If you use the hardwired download_models.sh, this will still run the same.
if [ -x /opt/download_models.sh ]; then
  /opt/download_models.sh \
    --checkpoints-urls "${CHECKPOINT_URLS}" \
    --vae-urls "${VAE_URLS}" \
    --lora-urls "${LORA_URLS}" \
    --diffusion-urls "${DIFFUSION_MODEL_URLS}" \
    --text-encoder-urls "${TEXT_ENCODER_URLS}" \
    --frame-interp-urls "${FRAME_INTERP_URLS}" \
    --checkpoint-ids "${CHECKPOINT_VERSION_IDS}" \
    --vae-ids "${VAE_VERSION_IDS}" \
    --lora-ids "${LORA_VERSION_IDS}" \
    --civitai-token "${CIVITAI_TOKEN}"
fi

# 6) --- NEW: Launch JupyterLab in the background ---
echo "[*] Starting JupyterLab on 0.0.0.0:${JUPYTER_PORT} (logs → /workspace/jupyter.log)"
# If you want to force a fixed token, add:  --ServerApp.token="${JUPYTER_TOKEN}"
nohup jupyter lab --ip=0.0.0.0 --port "${JUPYTER_PORT}" --no-browser \
  > /workspace/jupyter.log 2>&1 &

# 7) Launch ComfyUI
echo "[*] Launching ComfyUI on 0.0.0.0:${COMFY_PORT}"
exec python3 "${COMFY_PATH}/main.py" --listen 0.0.0.0 --port "${COMFY_PORT}"
