import json
import os
import sys

lock = json.load(sys.stdin)
source = os.environ.get("source")

name = lock["_generic"]["defaultPackage"]
version = lock["_generic"]["packages"][name]

# follow the original source file
lock["sources"][name][version]["path"] = source

print(json.dumps(lock, indent=2))
