#!/usr/bin/env bash
set -euo pipefail

# === Where files must live (ComfyUI standard) ===
DIFF_DIR="/ComfyUI/models/diffusion_models"
TXT_DIR="/ComfyUI/models/text_encoders"
VAE_DIR="/ComfyUI/models/vae"
LORA_DIR="/ComfyUI/models/loras"

mkdir -p "$DIFF_DIR" "$TXT_DIR" "$VAE_DIR" "$LORA_DIR"

# === WAN 2.2 (I2V, 14B, fp16) ===
WAN22_HIGH_URL="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors"
WAN22_LOW_URL="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp16.safetensors"
WAN22_HIGH_NAME="wan2.2_i2v_high_noise_14B_fp16.safetensors"
WAN22_LOW_NAME="wan2.2_i2v_low_noise_14B_fp16.safetensors"

# === WAN 2.1 VAE ===
WAN21_VAE_URL="https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors?download=true"
WAN21_VAE_NAME="wan_2.1_vae.safetensors"

# === Text encoder UMT5 ===
UMT5_URL="https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors?download=true"
UMT5_NAME="umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# === Read Civitai-related env vars (RunPod passes these automatically) ===
CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"
LORA_VERSION_IDS="${LORA_VERSION_IDS:-}"

# --- helpers ---
dl_as () {
  local url="$1" dest_dir="$2" dest_name="$3"
  [ -z "$url" ] && { echo "  [!] missing URL for $dest_name — skipping"; return 0; }
  mkdir -p "$dest_dir"
  if [ -f "$dest_dir/$dest_name" ]; then
    echo "  [=] $dest_name already exists — skipping download"
    return 0
  fi
  echo "  [*] downloading: $dest_name"
  aria2c -q --allow-overwrite=true --auto-file-renaming=false \
    -o "$dest_name" -d "$dest_dir" "$url" || {
      echo "  [!] failed to download $dest_name"; return 1;
    }
}

echo "[*] Ensuring required models are present…"

# 1) WAN 2.2 high/low diffusion models
dl_as "$WAN22_HIGH_URL" "$DIFF_DIR" "$WAN22_HIGH_NAME"
dl_as "$WAN22_LOW_URL"  "$DIFF_DIR" "$WAN22_LOW_NAME"

# 2) UMT5 text encoder
dl_as "$UMT5_URL" "$TXT_DIR" "$UMT5_NAME"

# 3) WAN 2.1 VAE
dl_as "$WAN21_VAE_URL" "$VAE_DIR" "$WAN21_VAE_NAME"

# 4) LoRAs from Civitai (using version IDs + token)
if [ -n "$LORA_VERSION_IDS" ]; then
  IFS=',' read -ra IDS <<< "$LORA_VERSION_IDS"
  echo "[*] Downloading LoRAs from Civitai..."
  for id in "${IDS[@]}"; do
    url="https://civitai.com/api/download/models/${id}"
    [ -n "$CIVITAI_TOKEN" ] && url="${url}?token=${CIVITAI_TOKEN}"
    echo "    ↳ version ${id}"
    aria2c -q --allow-overwrite=true --auto-file-renaming=false -d "$LORA_DIR" "$url" || true
  done
fi

echo "[*] All required models checked."
