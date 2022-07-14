import json
import os
import pathlib
import shutil
import subprocess as sp
import sys


out = os.environ.get('out')
pname = os.environ.get('packageName')
version = os.environ.get('version')
bin_dir = f"{os.path.abspath('..')}/.bin"
root = f"{os.path.abspath('.')}/node_modules"
package_json_cache = {}


with open(os.environ.get("nodeDepsPath")) as f:
  nodeDeps = f.read().split()

def get_package_json(path):
  if path not in package_json_cache:
    if not os.path.isfile(f"{path}/package.json"):
      return None
    with open(f"{path}/package.json") as f:
      package_json_cache[path] = json.load(f)
  return package_json_cache[path]

def install_direct_dependencies():
  add_to_bin_path = []
  if not os.path.isdir(root):
    os.mkdir(root)
  with open(os.environ.get('nodeDepsPath')) as f:
    deps = f.read().split()
  for dep in deps:
    # check for bin directory
    if os.path.isdir(f"{dep}/bin"):
      add_to_bin_path.append(f"{dep}/bin")
    if os.path.isdir(f"{dep}/lib/node_modules"):
      for module in os.listdir(f"{dep}/lib/node_modules"):
        # ignore hidden directories
        if module[0] == ".":
          continue
        if module[0] == '@':
          for submodule in os.listdir(f"{dep}/lib/node_modules/{module}"):
            pathlib.Path(f"{root}/{module}").mkdir(exist_ok=True)
            print(f"installing: {module}/{submodule}")
            origin =\
              os.path.realpath(f"{dep}/lib/node_modules/{module}/{submodule}")
            os.symlink(origin, f"{root}/{module}/{submodule}")
        else:
          print(f"installing: {module}")
          origin = os.path.realpath(f"{dep}/lib/node_modules/{module}")
          if not os.path.isdir(f"{root}/{module}"):
            os.symlink(origin, f"{root}/{module}")
          else:
            print(f"already exists: {root}/{module}")

  return add_to_bin_path


def collect_dependencies(root, depth):
  if not os.path.isdir(root):
    return []
  dirs = os.listdir(root)

  currentDeps = []
  for d in dirs:
    if d.rpartition('/')[-1].startswith('@'):
      subdirs = os.listdir(f"{root}/{d}")
      for sd in subdirs:
        cur_dir = f"{root}/{d}/{sd}"
        currentDeps.append(f"{cur_dir}")
    else:
      cur_dir = f"{root}/{d}"
      currentDeps.append(cur_dir)

  if depth == 0:
    return currentDeps
  else:
    depsOfDeps =\
      map(lambda dep: collect_dependencies(f"{dep}/node_modules", depth - 1), currentDeps)
    result = []
    for deps in depsOfDeps:
      result += deps
    return result


def symlink_sub_dependencies():
  for dep in collect_dependencies(root, 1):
    # compute module path
    d1, d2 = dep.split('/')[-2:]
    if d1.startswith('@'):
      path = f"{root}/{d1}/{d2}"
    else:
      path = f"{root}/{d2}"

    # check for collision
    if os.path.isdir(path):
      continue

    # create parent dir
    pathlib.Path(os.path.dirname(path)).mkdir(parents=True, exist_ok=True)

    # symlink dependency
    os.symlink(os.path.realpath(dep), path)


# create symlinks for executables (bin entries from package.json)
def symlink_bin(bin_dir, package_location, package_json):
  if 'bin' in package_json and package_json['bin']:
    bin = package_json['bin']

    def link(name, relpath):
      source = f'{bin_dir}/{name}'
      sourceDir = os.path.dirname(source)
      # create parent dir
      pathlib.Path(sourceDir).mkdir(parents=True, exist_ok=True)
      dest = os.path.relpath(f'{package_location}/{relpath}', sourceDir)
      print(f"symlinking executable. dest: {dest}; source: {source}")
      if not os.path.exists(source):
        os.symlink(dest, source)

    if isinstance(bin, str):
      name = package_json['name'].split('/')[-1]
      link(name, bin)

    else:
      for name, relpath in bin.items():
        link(name, relpath)


# checks if dependency is already installed in the current or parent dir.
def dependency_satisfied(root, pname, version):
  if root == "/nix/store":
    return False

  parent = os.path.dirname(root)

  if os.path.isdir(f"{root}/{pname}"):
    package_json_file = f"{root}/{pname}/package.json"
    if os.path.isfile(package_json_file):
      if version == get_package_json(f"{root}/{pname}").get('version'):
        return True

  return dependency_satisfied(parent, pname, version)


# transforms symlinked dependencies into real copies
def symlinks_to_copies(node_modules):
  sp.run(f"chmod +wx {node_modules}".split())
  for dep in collect_dependencies(node_modules, 0):

    # only handle symlinks to directories
    if not os.path.islink(dep) or os.path.isfile(dep):
      continue

    d1, d2 = dep.split('/')[-2:]
    if d1[0] == '@':
      pname = f"{d1}/{d2}"
      sp.run(f"chmod +wx {node_modules}/{d1}".split())
    else:
      pname = d2

    package_json = get_package_json(dep)
    if package_json is not None:
      version = package_json['version']
      if dependency_satisfied(os.path.dirname(node_modules), pname, version):
        os.remove(dep)
        continue

    print(f"copying {dep}")
    os.rename(dep, f"{dep}.bac")
    os.mkdir(dep)
    contents = os.listdir(f"{dep}.bac")
    if contents != []:
      for node in contents:
        if os.path.isdir(f"{dep}.bac/{node}"):
          shutil.copytree(f"{dep}.bac/{node}", f"{dep}/{node}", symlinks=True)
          if os.path.isdir(f"{dep}/node_modules"):
            symlinks_to_copies(f"{dep}/node_modules")
        else:
          shutil.copy(f"{dep}.bac/{node}", f"{dep}/{node}")
    os.remove(f"{dep}.bac")
    symlink_bin(f"{bin_dir}", dep, package_json)


# install direct deps
add_to_bin_path = install_direct_dependencies()

# dump bin paths
with open(f"{os.environ.get('TMP')}/ADD_BIN_PATH", 'w') as f:
  f.write(':'.join(add_to_bin_path))

# symlink non-colliding deps
symlink_sub_dependencies()

# symlinks to copies
if os.environ.get('installMethod') == 'copy':
  symlinks_to_copies(root)
