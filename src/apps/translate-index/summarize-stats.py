import json
import os
import sys


failed_proj_ids = list(os.listdir('translation-errors'))
print("saving list of failed projects in ./translation-errors.json")
print("failure logs can be found in ./translation-errors/")
with open(sys.argv[1], 'w') as f:
  json.dump(failed_proj_ids, f, indent=2)
