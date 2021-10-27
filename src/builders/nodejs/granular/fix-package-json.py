import json
import os
import sys


with open(sys.argv[1]) as f:
  actual_deps = json.load(f)

with open(sys.argv[2]) as f:
  package_json = json.load(f)

changed = False

# fail if platform incompatible
if 'os' in package_json:
  platform = sys.platform
  if platform not in package_json['os']\
      or f"!{platform}" in package_json['os']:
    print(
      f"Package is not compatible with current platform '{platform}'",
      file=sys.stderr
    )
    exit(3)

# replace version
version = os.environ.get("version")
if package_json['version'] != version:
  print(
    "WARNING: Replacing version in package.json: "
    f"{package_json['version']} -> {version}",
    file=sys.stderr
  )
  changed = True
  package_json['version'] = version

# delete devDependencies
if 'devDependencies' in package_json:
  print(
    f"Removing devDependencies from package.json",
    file=sys.stderr
  )
  changed = True
  del package_json['devDependencies']

# delete peerDependencies
if 'peerDependencies' in package_json:
  print(
    f"Removing peerDependencies from package.json",
    file=sys.stderr
  )
  changed = True
  del package_json['peerDependencies']

# pinpoint exact versions
if 'dependencies' in package_json:
  for pname, version in package_json['dependencies'].items():
    if actual_deps[pname] != package_json['dependencies'][pname]:
      package_json['dependencies'][pname] = actual_deps[pname]
      changed = True
      print(
        f"Replacing loose version '{version}' with '{actual_deps[pname]}'"
        f" for dependency '{pname}' in package.json",
        file=sys.stderr
      )

# write changes to package.json
if changed:
  with open(sys.argv[2], 'w') as f:
    json.dump(package_json, f, indent=2)
