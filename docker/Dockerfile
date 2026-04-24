# =========================================================
# PerAct Dockerfile (pip-based via uv, GPU-ready)
# =========================================================
FROM nvidia/cuda:11.0.3-cudnn8-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV VIRTUAL_ENV=/opt/venv
ENV PATH=/opt/venv/bin:/root/.local/bin:$PATH
ENV CUDA_HOME=/usr/local/cuda
# pytorch3d builds during `docker build` where no GPU is attached;
# cpp_extension cannot auto-detect arch and silently produces empty arch list.
# Pin explicitly to archs available under CUDA 11.0.
ENV TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0+PTX"
# Default mount point for CoppeliaSim binary (provided by user)
ENV COPPELIASIM_ROOT=/coppeliasim

# ---------------------------------------------------------
# System deps: CoppeliaSim / OpenGL rendering + CUDA ext build
# ---------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    bzip2 \
    ca-certificates \
    git \
    build-essential \
    cmake \
    python3.8 \
    python3.8-dev \
    python3.8-venv \
    libgl1 \
    libglib2.0-0 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libsm6 \
    libegl1 \
    libosmesa6 \
    qt5-default \
    libqt5x11extras5 \
    ffmpeg \
    lsof \
    psmisc \
    tmux \
    vim \
    x11-apps \
 && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# Install uv (static binary from official image)
# ---------------------------------------------------------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# ---------------------------------------------------------
# Create Python 3.8 venv managed by uv
# ---------------------------------------------------------
RUN uv venv /opt/venv --python 3.8

# ---------------------------------------------------------
# torch 1.7.1 + CUDA 11.0 wheel (must be installed first to
# prevent requirements.txt from pulling the CPU-only variant)
# ---------------------------------------------------------
RUN uv pip install \
    torch==1.7.1+cu110 \
    torchvision==0.8.2+cu110 \
    -f https://download.pytorch.org/whl/torch_stable.html

# ---------------------------------------------------------
# pytorch3d 0.3.0 compiled from source (no pre-built wheel for
# torch 1.7.1 + cu110 on PyPI; source build requires nvcc from devel image).
# --no-build-isolation: pytorch3d setup.py imports torch at build time;
# uv's isolated build env has no torch, so we reuse the venv directly.
# ---------------------------------------------------------
RUN uv pip install setuptools wheel \
 && uv pip install --no-build-isolation \
    "git+https://github.com/facebookresearch/pytorch3d.git@v0.3.0"

# ---------------------------------------------------------
# PyRep: clone into /opt/third_party so it's available at build time,
# but install is deferred to entrypoint (setup.py reads
# $COPPELIASIM_ROOT/system/usrset.txt, which only exists after the
# CoppeliaSim volume is mounted at runtime).
# ---------------------------------------------------------
RUN git clone https://github.com/stepjam/PyRep.git /opt/third_party/PyRep

# ---------------------------------------------------------
# RLBench peract fork (editable install into /opt/third_party)
# requirements.txt must be installed separately (uv pip install -e
# does not read requirements.txt, only setup.py install_requires)
# ---------------------------------------------------------
RUN mkdir -p /opt/third_party \
 && git clone -b peract https://github.com/MohitShridhar/RLBench.git \
      /opt/third_party/RLBench \
 && uv pip install -r /opt/third_party/RLBench/requirements.txt \
 && uv pip install -e /opt/third_party/RLBench

# ---------------------------------------------------------
# YARR peract fork (editable install)
# ---------------------------------------------------------
RUN git clone -b peract https://github.com/MohitShridhar/YARR.git \
      /opt/third_party/YARR \
 && uv pip install -e /opt/third_party/YARR

# ---------------------------------------------------------
# OpenAI CLIP
# ---------------------------------------------------------
RUN uv pip install git+https://github.com/openai/CLIP.git

# ---------------------------------------------------------
# Remaining peract requirements.
# torch and torchvision lines are filtered out to preserve the
# cu110 wheels already installed above.
# ---------------------------------------------------------
WORKDIR /workspace
COPY requirements.txt ./
RUN grep -vE '^torch==|^torchvision==' requirements.txt > /tmp/req_filtered.txt \
 && uv pip install -r /tmp/req_filtered.txt

# ---------------------------------------------------------
# Policy WebSocket library (shared by run_demo.py, run_eval.py,
# and tests/test_random_policy_server.py)
# ---------------------------------------------------------
RUN uv pip install git+https://github.com/YufengJin/policy_websocket.git

# ---------------------------------------------------------
# imageio + ffmpeg plugin for MP4 video saving in run_demo.py /
# run_eval.py when --save_video is on. System ffmpeg binary is
# already installed above; imageio_ffmpeg bundles a fallback.
# ---------------------------------------------------------
RUN uv pip install "imageio[ffmpeg]"

# ---------------------------------------------------------
# Entrypoint (peract itself is installed editable at container start
# from the mounted workspace source)
# ---------------------------------------------------------
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
