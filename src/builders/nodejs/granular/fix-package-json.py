import json
import sys


with open(sys.argv[1]) as f:
  actual_deps = json.load(f)

with open(sys.argv[2]) as f:
  package_json = json.load(f)

changed = False

# delete devDependencies
if 'devDependencies' in package_json:
  print(
    f"Removing devDependencies from package.json",
    file=sys.stderr
  )
  changed = True
  del package_json['devDependencies']

if 'dependencies' in package_json:
  for pname, version in package_json['dependencies'].items():
    if actual_deps[pname] != package_json['dependencies'][pname]:
      package_json['dependencies'][pname] = actual_deps[pname]
      changed = True
      print(
        f"Replacing loose version '{version}' with '{actual_deps[pname]}' for dependency '{pname}' in package.json",
        file=sys.stderr
      )

if changed:
  with open(sys.argv[2], 'w') as f:
    json.dump(package_json, f, indent=2)
