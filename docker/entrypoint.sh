#!/usr/bin/env bash
set -e

cd /workspace

# ---------------------------------------------------------
# 1. Project root detection
#    Supports nested mount: parent dir mounted at /workspace,
#    so source may live at /workspace/peract or /workspace.
# ---------------------------------------------------------
PERACT_ROOT=""
if [ -f /workspace/peract/setup.py ]; then
  PERACT_ROOT="/workspace/peract"
elif [ -f /workspace/setup.py ]; then
  PERACT_ROOT="/workspace"
fi

# ---------------------------------------------------------
# 2. CoppeliaSim runtime setup
#    The binary must be mounted by the user (see docker-compose).
#    Set env vars before any PyRep / RLBench import.
# ---------------------------------------------------------
if [ ! -f "${COPPELIASIM_ROOT}/coppeliaSim.sh" ]; then
  echo "================================================================"
  echo "WARNING: CoppeliaSim not found at COPPELIASIM_ROOT=${COPPELIASIM_ROOT}"
  echo "PyRep and RLBench will fail to import until it is mounted."
  echo ""
  echo "Download CoppeliaSim V4.1.0 for Ubuntu 20.04, unpack it, then"
  echo "set COPPELIASIM_ROOT in your environment before running compose:"
  echo "  export COPPELIASIM_ROOT=/path/to/CoppeliaSim_Player_V4_1_0_Ubuntu20_04"
  echo "  docker compose -f docker/docker-compose.headless.yaml up -d"
  echo "================================================================"
else
  export LD_LIBRARY_PATH="${COPPELIASIM_ROOT}:${LD_LIBRARY_PATH:-}"
  export QT_QPA_PLATFORM_PLUGIN_PATH="${COPPELIASIM_ROOT}"
fi

if [ -n "${PERACT_ROOT}" ]; then
  # ---------------------------------------------------------
  # 3. Install PyRep (deferred from Dockerfile because setup.py writes to
  #    $COPPELIASIM_ROOT/system/usrset.txt, which only exists after mount).
  #    Trigger: CoppeliaSim binary present AND pyrep not yet importable.
  # ---------------------------------------------------------
  if [ -f "${COPPELIASIM_ROOT}/coppeliaSim.sh" ] \
     && ! python -c "import pyrep" 2>/dev/null; then
    echo ">> Installing PyRep (requires CoppeliaSim at ${COPPELIASIM_ROOT})..."
    uv pip install -e /opt/third_party/PyRep
  fi

  # ---------------------------------------------------------
  # 4. Editable install of peract from mounted source
  # ---------------------------------------------------------
  echo ">> Installing peract from ${PERACT_ROOT} (editable)..."
  uv pip install -e "${PERACT_ROOT}" --no-deps

  # 5. Checkpoint hint
  CKPT_DIR="${PERACT_ROOT}/ckpts"
  if [ ! -d "${CKPT_DIR}" ] || [ -z "$(ls -A "${CKPT_DIR}" 2>/dev/null)" ]; then
    echo "[INFO] No checkpoints found at ${CKPT_DIR}."
    echo "       To download a pre-trained agent run:"
    echo "         cd \${PERACT_ROOT} && sh scripts/quickstart_download.sh"
  fi
fi

if [ $# -eq 0 ]; then
  exec bash
else
  exec "$@"
fi
