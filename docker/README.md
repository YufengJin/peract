# PerAct Docker Guide

Run PerAct (train / eval) inside a GPU-ready container that mirrors the robocasa / LIBERO docker layout.

## Prerequisites

- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed and configured.
- **CoppeliaSim V4.1.0 Player** (Ubuntu 20.04, ~63MB, free) — install with one command:

```bash
bash scripts/install_coppeliasim.sh
```

Installs into `third_party/CoppeliaSim/` (inside the peract repo) and handles the
PyRep pre-requisites (`usrset.txt` + `libcoppeliaSim.so.1` symlink). The compose
files default to this location, so `COPPELIASIM_ROOT` does not need to be exported.

To use a CoppeliaSim install located elsewhere, set `COPPELIASIM_ROOT=/path/to/dir`
before running `docker compose up`.

## Build

```bash
cd /path/to/peract          # repo root
docker compose -f docker/docker-compose.headless.yaml build
```

First build is slow (~15–20 min) because `pytorch3d==0.3.0` is compiled from source. Subsequent builds reuse Docker layer cache.

## Start (headless)

```bash
docker compose -f docker/docker-compose.headless.yaml up -d
docker exec -it peract_container bash
```

## Start (GUI / X11)

```bash
xhost +local:docker
docker compose -f docker/docker-compose.x11.yaml up -d
docker exec -it peract_container bash
```

## Smoke Test

```bash
# GPU
docker exec -it peract_container nvidia-smi

# Editable install: peract has no top-level 'peract' package; verify via helpers/agents/voxel
docker exec -it peract_container python -c "import helpers; print(helpers.__file__)"
# expected: /workspace/helpers/__init__.py

# torch + CUDA
docker exec -it peract_container python -c "import torch; print(torch.cuda.is_available(), torch.__version__)"
# expected: True  1.7.1+cu110

# pytorch3d (compiled from source)
docker exec -it peract_container python -c "import pytorch3d; print(pytorch3d.__version__)"
# expected: 0.3.0

# CLIP and YARR
docker exec -it peract_container python -c "import clip; print('clip ok')"
docker exec -it peract_container python -c "import yarr; print(yarr.__file__)"
# expected: /opt/third_party/YARR/yarr/__init__.py

# RLBench + PyRep (require CoppeliaSim to be mounted)
docker exec -it peract_container python -c "from rlbench import CameraConfig; print('rlbench ok')"
```

## End-to-end smoke test (L3_IL)

Verifies the full generated IL stack: random-policy WebSocket server ↔ `run_eval.py` client ↔ RLBench `task.step()`. No checkpoints, no dataset needed.

```bash
# 1. Start the companion random-policy server in background
docker exec -d peract_container python tests/test_random_policy_server.py --port 8000

# 2. Wait for port 8000 to accept connections
docker exec peract_container python -c "import socket, time
for _ in range(20):
    try: socket.create_connection(('127.0.0.1', 8000), timeout=1).close(); print('ready'); break
    except OSError: time.sleep(0.5)"

# 3. Single-episode demo against the test server
docker exec peract_container python scripts/run_demo.py \
    --policy_server_addr localhost:8000 \
    --n-steps 10 --task open_drawer

# 4. Eval harness against the test server
docker exec peract_container python scripts/run_eval.py \
    --policy_server_addr localhost:8000 \
    --n-episodes 1 --max-steps 20 --task open_drawer

# 5. Clean up
docker exec peract_container pkill -f test_random_policy_server
```

Expected: `run_eval.py` prints `server metadata: {...}` and `success_rate: 0.000` (random policy never solves the task — success of the smoke test is reaching this line without crashing).

## Run eval (inside container)

```bash
export PERACT_ROOT=/workspace/peract

# Download pre-trained checkpoint (one-time)
cd $PERACT_ROOT && sh scripts/quickstart_download.sh

# Generate a small val set
cd /opt/third_party/RLBench/tools
python dataset_generator.py \
    --tasks=open_drawer \
    --save_path=$PERACT_ROOT/data/val \
    --image_size=128,128 \
    --renderer=opengl \
    --episodes_per_task=10 \
    --processes=1 \
    --all_variations=True

# Evaluate
cd $PERACT_ROOT
CUDA_VISIBLE_DEVICES=0 python eval.py \
    rlbench.tasks=[open_drawer] \
    rlbench.task_name='multi' \
    rlbench.demo_path=$PERACT_ROOT/data/val \
    framework.gpu=0 \
    framework.logdir=$PERACT_ROOT/ckpts/ \
    framework.start_seed=0 \
    framework.eval_envs=1 \
    framework.eval_from_eps_number=0 \
    framework.eval_episodes=10 \
    framework.csv_logging=True \
    framework.tensorboard_logging=True \
    framework.eval_type='last' \
    rlbench.headless=True
```

## Troubleshooting

**OpenGL / EGL errors**

```bash
export DISPLAY=:0
export MESA_GL_VERSION_OVERRIDE=4.1
export PYOPENGL_PLATFORM=egl
```

**`pyrep.errors.ConfigurationError: CoppeliaSim not found`**

The container cannot find the CoppeliaSim binary. Confirm that:
1. `third_party/CoppeliaSim/coppeliaSim.sh` exists (run `bash scripts/install_coppeliasim.sh`).
2. If using a custom location, `COPPELIASIM_ROOT` is exported before `docker compose up`.

**`torch.cuda.is_available()` returns False**

Ensure NVIDIA Container Toolkit is installed (`nvidia-smi` works inside the container). The compose files set `NVIDIA_DRIVER_CAPABILITIES=all`.

**Stop the container**

```bash
docker compose -f docker/docker-compose.headless.yaml down
```
