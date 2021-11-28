import json
import os
import pathlib
import sys


out = os.environ.get('out')
pname = os.environ.get('packageName')
version = os.environ.get('version')
root = f"{out}/lib/node_modules/{pname}/node_modules"

if not os.path.isdir(root):
  exit()


with open(os.environ.get("nodeDepsPath")) as f:
  nodeDeps = f.read().split()

def getDependencies(root, depth):
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
      map(lambda dep: getDependencies(f"{dep}/node_modules", depth - 1), currentDeps)
    result = []
    for deps in depsOfDeps:
      result += deps
    return result

deps = getDependencies(root, 1)

# symlink deps non-colliding deps
for dep in deps:

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




