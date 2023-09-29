import subprocess
import json
import os
import multiprocessing
from multiprocessing.pool import ThreadPool

with open('spago.json', 'r') as spagoFile, open('packages.json', 'r') as packagesFile:
    spago = json.load(spagoFile)
    packagesSet = json.load(packagesFile)

dependencies = spago["package"]["dependencies"]
checked = set()

closure = set(dependencies)

def getDeps(deps):
    for dep in deps.copy():
        if dep in checked:
            continue
        checked.add(dep)
        closure.update(getDeps(set(packagesSet[dep]["dependencies"])))
    return deps

    
getDeps(set(dependencies))

lock = {}

def getSource(depName):
    dep = packagesSet[depName]
    repo = dep["repo"]
    version = dep["version"]
    rev = subprocess.run(["git", "ls-remote", repo, version], text=True, capture_output=True).stdout.split()[0]
    print(f"{repo}/{version}: {rev}")
    lock[depName] = dep
    lock[depName]["rev"] = rev

with ThreadPool(processes=multiprocessing.cpu_count()*2) as pool:
    pool.map_async(getSource, closure)
    pool.close()
    pool.join()

with open(os.environ.get("out"), "w") as f:
    json.dump(lock, f)
