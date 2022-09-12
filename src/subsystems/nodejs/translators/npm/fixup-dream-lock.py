import json
import os
import sys

lock = json.load(sys.stdin)
version = os.environ.get('version')

# set default package version correctly
defaultPackage = lock['_generic']['defaultPackage']
lock['_generic']['packages'] = {
  defaultPackage: version
}

print(json.dumps(lock, indent=2))
