import json
import sys
import os

out_file = sys.argv[1]
number = int(os.environ.get("number"))

input = json.load(sys.stdin)
projects = []
for package in input["crates"]:
    projects.append(
        dict(
            id=f"{package['name']}-{package['max_stable_version']}",
            name=package["name"],
            version=package["max_stable_version"],
            translator="crates-io",
        )
    )

with open(out_file) as f:
    existing_projects = json.load(f)

all_projects = (existing_projects + projects)[:number]
with open(out_file, "w") as f:
    json.dump(all_projects, f, indent=2)
