import json
import sys

input = json.load(sys.stdin)
projects = []
for object in input['objects']:
  package = object['package']
  projects.append(dict(
    id=f"{package['name']}-{package['version']}".replace('/', '_'),
    name=package['name'],
    version=package['version'],
    translator='npm',
  ))
print(json.dumps(projects, indent=2))
