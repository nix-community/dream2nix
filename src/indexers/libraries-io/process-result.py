import json
import os
import sys

out_file = sys.argv[1]
platform = os.environ.get("platform")
number = int(os.environ.get("number"))

if platform == "hackage":
  sort_key = lambda v: [int(n) for n in v['number'].split('.')]
else:
  sort_key = key=lambda v: v['published_at']

input = json.load(sys.stdin)
projects = []
for package in input:
  versions = package['versions']
  versions = sorted(versions, key=sort_key, reverse=True)
  if versions:
    # latest_stable_release_number is often wrong for hackage
    if platform == "hackage":
      latest_version = versions[0]['number']
    else:
      latest_version = package["latest_stable_release_number"]
      if latest_version == None:
        latest_version = versions[0]['number']
    projects.append(dict(
        id=f"{package['name']}-{latest_version}",
        name=package['name'],
        version=latest_version,
        translator=platform,
    ))

with open(out_file) as f:
  existing_projects = json.load(f)

all_projects = (existing_projects + projects)[:number]
with open(out_file, 'w') as f:
  json.dump(all_projects, f, indent=2)
