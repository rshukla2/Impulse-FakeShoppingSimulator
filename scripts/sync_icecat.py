#!/usr/bin/env python3
import asyncio, json, os, sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from scripts.sync_one import run_one
if __name__ == "__main__":
    print(json.dumps(asyncio.run(run_one("icecat")), indent=2))
