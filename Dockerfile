FROM pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime

# Create a non-root user
RUN groupadd -r appuser && useradd -r -m -g appuser appuser

# Set up the work directory and ensure the non-root user has permissions
RUN mkdir /app && chown -R appuser:appuser /app

# Switch to the non-root user
USER appuser

# Set the working directory
WORKDIR /app

# Install dependencies without using sudo
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    git \
    gcc \
    g++ \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Switch back to the non-root user
USER appuser

# Clone repositories
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git webui \
    && git clone https://github.com/Mikubill/sd-webui-controlnet webui/extensions/controlnet \
    && git clone https://github.com/Gourieff/sd-webui-reactor webui/extensions/reactor

WORKDIR /app/webui

# Create and activate a virtual environment
RUN python3 -m venv venv && . venv/bin/activate

# Install Python packages
RUN venv/bin/pip install -r requirements.txt
RUN venv/bin/pip install xformers

# Install additional Python packages
RUN venv/bin/pip install insightface runpod flask requests torchvision

# Download models
WORKDIR /app/webui/models/Stable-diffusion/
RUN wget -O absoluteReality.safetensors "https://civitai.com/api/download/models/132760?type=Model&format=SafeTensor&size=pruned&fp=fp16&token=07facdc51bce351ad0aa9e2b94e72f3f"
RUN wget https://huggingface.co/lllyasviel/ControlNet/resolve/main/models/control_sd15_canny.pth -P /app/webui/extensions/controlnet/models/
RUN wget https://huggingface.co/lllyasviel/ControlNet/resolve/main/models/control_sd15_depth.pth -P /app/webui/extensions/controlnet/models/
RUN wget https://huggingface.co/lllyasviel/ControlNet/resolve/main/models/control_sd15_mlsd.pth -P /app/webui/extensions/controlnet/models/
RUN wget https://huggingface.co/lllyasviel/ControlNet/resolve/main/models/control_sd15_normal.pth -P /app/webui/extensions/controlnet/models/
RUN wget https://huggingface.co/lllyasviel/ControlNet/resolve/main/models/control_sd15_openpose.pth -P /app/webui/extensions/controlnet/models/

WORKDIR /app/webui

# Copy handler script
COPY runpod_handler.py /app/webui/runpod_handler.py

# Start both the web UI and the runpod handler
CMD ["sh", "-c", "./webui.sh --listen --xformers --skip-torch-cuda-test --enable-insecure-extension-access --api --port 7860 & venv/bin/python /app/webui/runpod_handler.py"]
