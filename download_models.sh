#!/usr/bin/env bash
set -euo pipefail

CKPT_DIR="/ComfyUI/models/checkpoints"
VAE_DIR="/ComfyUI/models/vae"
LORA_DIR="/ComfyUI/models/loras"

CHECKPOINT_URLS=""; VAE_URLS=""; LORA_URLS=""
CHECKPOINT_IDS=""; VAE_IDS=""; LORA_IDS=""
CIVITAI_TOKEN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --checkpoints-urls) CHECKPOINT_URLS="$2"; shift 2;;
    --vae-urls)         VAE_URLS="$2"; shift 2;;
    --lora-urls)        LORA_URLS="$2"; shift 2;;
    --checkpoint-ids)   CHECKPOINT_IDS="$2"; shift 2;;
    --vae-ids)          VAE_IDS="$2"; shift 2;;
    --lora-ids)         LORA_IDS="$2"; shift 2;;
    --civitai-token)    CIVITAI_TOKEN="${2:-}"; shift 2;;
    *) shift 1;;
  esac
done

dl() {
  local url="$1" outdir="$2"
  [ -z "$url" ] && return 0
  mkdir -p "$outdir"
  echo "    ↳ $url"
  aria2c -q --allow-overwrite=true --auto-file-renaming=false -d "$outdir" "$url" || true
}

civitai_dl() {
  local version_id="$1" outdir="$2"
  [ -z "$version_id" ] && return 0
  mkdir -p "$outdir"
  local url="https://civitai.com/api/download/models/${version_id}"
  if [ -n "${CIVITAI_TOKEN}" ]; then
    url="${url}?token=${CIVITAI_TOKEN}"
  fi
  echo "    ↳ civitai version ${version_id}"
  aria2c -q --allow-overwrite=true --auto-file-renaming=false -d "$outdir" "$url" || true
}

if [ -n "$CHECKPOINT_URLS" ]; then
  IFS=',' read -ra A <<< "$CHECKPOINT_URLS"
  echo "[*] Downloading checkpoints (direct URLs)…"
  for u in "${A[@]}"; do dl "$u" "$CKPT_DIR"; done
fi

if [ -n "$VAE_URLS" ]; then
  IFS=',' read -ra A <<< "$VAE_URLS"
  echo "[*] Downloading VAEs (direct URLs)…"
  for u in "${A[@]}"; do dl "$u" "$VAE_DIR"; done
fi

if [ -n "$LORA_URLS" ]; then
  IFS=',' read -ra A <<< "$LORA_URLS"
  echo "[*] Downloading LoRAs (direct URLs)…"
  for u in "${A[@]}"; do dl "$u" "$LORA_DIR"; done
fi

if [ -n "$CHECKPOINT_IDS" ]; then
  IFS=',' read -ra A <<< "$CHECKPOINT_IDS"
  echo "[*] Downloading checkpoints (Civitai IDs)…"
  for id in "${A[@]}"; do civitai_dl "$id" "$CKPT_DIR"; done
fi

if [ -n "$VAE_IDS" ]; then
  IFS=',' read -ra A <<< "$VAE_IDS"
  echo "[*] Downloading VAEs (Civitai IDs)…"
  for id in "${A[@]}"; do civitai_dl "$id" "$VAE_DIR"; done
fi

if [ -n "$LORA_IDS" ]; then
  IFS=',' read -ra A <<< "$LORA_IDS"
  echo "[*] Downloading LoRAs (Civitai IDs)…"
  for id in "${A[@]}"; do civitai_dl "$id" "$LORA_DIR"; done
fi

echo "[*] Model downloads complete."
