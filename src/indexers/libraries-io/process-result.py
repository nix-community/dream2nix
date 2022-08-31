import json
import os
import sys

out_file = sys.argv[1]
platform = os.environ.get("platform")
number = int(os.environ.get("number"))

input = json.load(sys.stdin)
projects = []
for package in input:
  versions = package['versions']
  latest_version =\
    (sorted(versions, key=lambda v: v['published_at'])[-1])['number']
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
