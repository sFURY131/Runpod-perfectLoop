FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget curl aria2 ca-certificates python3 python3-venv python3-pip tini \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /workspace /ComfyUI/models/checkpoints /ComfyUI/models/vae /ComfyUI/models/loras /ComfyUI/models/upscale_models /ComfyUI/custom_nodes /workflows

COPY start.sh /opt/start.sh
COPY download_models.sh /opt/download_models.sh
RUN chmod +x /opt/start.sh /opt/download_models.sh

EXPOSE 8188
WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/opt/start.sh"]
