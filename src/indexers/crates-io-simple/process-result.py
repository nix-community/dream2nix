import json
import sys

input = json.load(sys.stdin)
projects = []
for package in input['crates']:
  projects.append(dict(
    id=f"{package['name']}-{package['max_stable_version']}",
    name=package['name'],
    version=package['max_stable_version'],
    translator='crates-io',
  ))
print(json.dumps(projects, indent=2))
