import json
import os
import pathlib
import sys


with open(os.environ.get('dependenciesJsonPath')) as f:
  available_deps = json.load(f)

with open('package.json') as f:
  package_json = json.load(f)

out = os.environ.get('out')
shouldBuild = os.environ.get('shouldBuild')

changed = False

# fail if platform incompatible - should not happen due to filters
if 'os' in package_json:
  platform = sys.platform
  if platform not in package_json['os']\
      or f"!{platform}" in package_json['os']:
    print(
      f"Package is not compatible with current platform '{platform}'",
      file=sys.stderr
    )
    exit(3)

if shouldBuild != '':
  # replace version
  # If it is a github dependency referred by revision,
  # we can not rely on the version inside the package.json.
  # In case of an 'unknown' version coming from the dream lock,
  # do not override the version from package.json
  version = os.environ.get("version")
  if version not in ["unknown", package_json.get('version')]:
    print(
      "WARNING: The version of this package defined by its package.json "
      "doesn't match the version expected by dream2nix."
      "\n  -> Replacing version in package.json: "
      f"{package_json.get('version')} -> {version}",
      file=sys.stderr
    )
    package_json['origVersion'] = package_json['version'] 
    package_json['version'] = version


  # pinpoint exact versions
  # This is mostly needed to replace git references with exact versions,
  # as NPM install will otherwise re-fetch these
  if 'dependencies' in package_json:
    dependencies = package_json['dependencies']
    depsChanged = False
    # dependencies can be a list or dict
    for pname in dependencies:
      if 'bundledDependencies' in package_json\
          and pname in package_json['bundledDependencies']:
        continue
      if pname not in available_deps:
        print(
          f"WARNING: Dependency {pname} wanted but not available. Ignoring.",
          file=sys.stderr
        )
        depsChanged = True
        continue
      version =\
        'unknown' if isinstance(dependencies, list) else dependencies[pname]
      if available_deps[pname] != version:
        depsChanged = True
        print(
          f"package.json: Pinning version '{version}' to '{available_deps[pname]}'"
          f" for dependency '{pname}'",
          file=sys.stderr
        )
    if depsChanged:
      changed = True
      package_json['dependencies'] = available_deps
      package_json['origDependencies'] = dependencies

# create symlinks for executables (bin entries from package.json)
def symlink_bin(bin_dir, package_json):
  if 'bin' in package_json and package_json['bin']:
    bin = package_json['bin']

    def link(name, relpath):
      source = f'{bin_dir}/{name}'
      sourceDir = os.path.dirname(source)
      # make target executable
      os.chmod(relpath, 0o777)
      # create parent dir
      pathlib.Path(sourceDir).mkdir(parents=True, exist_ok=True)
      dest = os.path.relpath(relpath, sourceDir)
      print(f"symlinking executable. dest: {dest}; source: {source}")
      os.symlink(dest, source)

    if isinstance(bin, str):
      name = (package_json['name'].split('/')[-1]).rsplit('.js', 1)[0]
      link(name, bin)

    else:
      for name, relpath in bin.items():
        link(name, relpath)

# symlink current packages executables to $out/bin
symlink_bin(f'{out}/bin/', package_json)

# write changes to package.json
if changed:
  with open('package.json', 'w') as f:
    json.dump(package_json, f, indent=2)
