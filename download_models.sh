#!/usr/bin/env bash
set -euo pipefail

# === Where files must live (ComfyUI standard) ===
DIFF_DIR="/ComfyUI/models/diffusion_models"
TXT_DIR="/ComfyUI/models/text_encoders"
VAE_DIR="/ComfyUI/models/vae"

mkdir -p "$DIFF_DIR" "$TXT_DIR" "$VAE_DIR"

# === WAN 2.2 (I2V, 14B, fp16) — YOU MUST FILL THESE TWO URLS ===
# Put direct links that actually return the .safetensors file.
WAN22_HIGH_URL="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors"
WAN22_LOW_URL="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp16.safetensors"

# Exact filenames your workflow expects:
WAN22_HIGH_NAME="wan2.2_i2v_high_noise_14B_fp16.safetensors"
WAN22_LOW_NAME="wan2.2_i2v_low_noise_14B_fp16.safetensors"

# === WAN 2.1 VAE (known public link) ===
WAN21_VAE_URL="https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors?download=true"
WAN21_VAE_NAME="wan_2.1_vae.safetensors"

# === Text encoder UMT5 (known public link) ===
UMT5_URL="https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors?download=true"
UMT5_NAME="umt5_xxl_fp8_e4m3fn_scaled.safetensors"

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

echo "[*] All required models checked."
