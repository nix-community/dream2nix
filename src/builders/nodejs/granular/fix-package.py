import json
import os
import pathlib
import sys


with open(os.environ.get('dependenciesJsonPath')) as f:
  available_deps = json.load(f)

with open('package.json') as f:
  package_json = json.load(f)

out = os.environ.get('out')

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
# If it is a github dependency referred by revision,
# we can not rely on the version inside the package.json
version = os.environ.get("version")
if package_json['version'] != version:
  print(
    "WARNING: The version of this package defined by its package.json "
    "doesn't match the version expected by dream2nix."
    "\n  -> Replacing version in package.json: "
    f"{package_json['version']} -> {version}",
    file=sys.stderr
  )
  changed = True
  package_json['version'] = version


# pinpoint exact versions
# This is mostly needed to replace git references with exact versions,
# as NPM install will otherwise re-fetch these
if 'dependencies' in package_json:
  for pname, version in package_json['dependencies'].items():
    if 'bundledDependencies' in package_json\
        and pname in package_json['bundledDependencies']:
      continue
    if pname not in available_deps:
      print(
        f"WARNING: Dependency {pname} wanted but not available. Ignoring.",
        file=sys.stderr
      )
      continue
    if available_deps[pname] != package_json['dependencies'][pname]:
      package_json['dependencies'][pname] = available_deps[pname]
      changed = True
      print(
        f"package.json: Pinning version '{version}' to '{available_deps[pname]}'"
        f" for dependency '{pname}'",
        file=sys.stderr
      )

# create symlinks for executables (bin entries from package.json)
if 'bin' in package_json:
  bin = package_json['bin']

  if isinstance(bin, str):
    name = package_json['name']
    if not os.path.isfile(bin):
      raise Exception(f"binary specified in package.json doesn't exist: {bin}")
    source = f'{out}/lib/node_modules/.bin/{name}'
    sourceDir = os.path.dirname(source)
    # create parent dir
    pathlib.Path(sourceDir).mkdir(parents=True, exist_ok=True)
    
    dest = os.path.relpath(bin, sourceDir)
    print(f"dest: {dest}; source: {source}")
    os.symlink(dest, source)

  else:
    for bin_name, relpath in bin.items():
      source = f'{out}/lib/node_modules/.bin/{bin_name}'
      sourceDir = os.path.dirname(source)
      # create parent dir
      pathlib.Path(sourceDir).mkdir(parents=True, exist_ok=True)
      dest = os.path.relpath(relpath, sourceDir)
      os.symlink(dest, source)

# write changes to package.json
if changed:
  with open('package.json', 'w') as f:
    json.dump(package_json, f, indent=2)
