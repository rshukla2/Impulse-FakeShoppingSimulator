#!/usr/bin/env python3
import argparse, asyncio, json, os, sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from scripts.sync_one import run_one
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--country", action="append")
    args = parser.parse_args()
    print(json.dumps(asyncio.run(run_one("openfoodfacts", args.country)), indent=2))
