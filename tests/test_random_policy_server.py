#!/usr/bin/env python3
"""Test policy server for peract — returns random 8-D actions via WebSocket.

Purpose
-------
Smoke-test companion for scripts/run_demo.py and scripts/run_eval.py. Both
clients are WebSocket policy clients and need a server to talk to; this file
is that server. Random 8-D actions (xyz + quat + gripper) never solve an
RLBench task — the server exists purely to exercise the wiring end-to-end
(handshake, msgpack serialization, action shape guard, env stepping). Swap
it for a trained-policy server (same protocol) in real evaluation.

Headless by construction — no GUI, no env, no dataset. Pure WS server.

Example
-------
    # Terminal A — start the server
    python tests/test_random_policy_server.py --port 8000

    # Terminal B — point a client at it
    python scripts/run_demo.py --policy_server_addr localhost:8000 \\
        --task open_drawer --n-steps 10
    python scripts/run_eval.py --policy_server_addr localhost:8000 \\
        --task open_drawer --n-episodes 1

The `action_dim` advertised in metadata (8) MUST match what RLBench expects
for `MoveArmThenGripper(EndEffectorPoseViaPlanning, Discrete)`, or the
client's handshake guard raises `ValueError` on every connection.
"""
from __future__ import annotations

import argparse
import logging
from typing import Dict

import numpy as np

from policy_websocket import BasePolicy, WebsocketPolicyServer


ACTION_DIM = 8


def _sample_action() -> np.ndarray:
    """Random but plausible 8-D (xyz + quat + gripper). Mostly unreachable,
    which is fine — the server only tests the protocol, not the policy.
    """
    return np.concatenate([
        np.random.uniform([-0.3, -0.3, 0.9], [0.3, 0.3, 1.3], 3),
        np.array([0.0, 0.0, 0.0, 1.0]),
        np.array([1.0]),
    ]).astype(np.float32)


class RandomPolicy(BasePolicy):
    def infer(self, obs: Dict) -> Dict:
        action = _sample_action()
        assert action.shape == (ACTION_DIM,), \
            f"produced {action.shape}, expected ({ACTION_DIM},)"
        return {"actions": action}

    def reset(self) -> None:
        pass


def main():
    parser = argparse.ArgumentParser(
        description="peract test policy server (random actions, headless)")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    server = WebsocketPolicyServer(
        policy=RandomPolicy(),
        host=args.host,
        port=args.port,
        metadata={"policy_name": "RandomPolicy(peract)", "action_dim": ACTION_DIM},
    )
    print(f"Starting peract RandomPolicy server on ws://{args.host}:{args.port}")
    print(f"Advertising action_dim={ACTION_DIM}. Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    print("Server stopped.")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s %(name)s %(levelname)s %(message)s")
    main()
