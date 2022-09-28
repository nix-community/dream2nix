import sys
import json

def replace_root_sources(lock, newSource):

    packages = lock['_generic']['packages']
    sources = lock['sources']

    for name, version in packages.items():

        original = sources[name][version]

        fixed = newSource

        if 'dir' in original:
            fixed['dir'] = original['dir']
        elif 'relPath' in original:
            fixed['dir'] = original['relPath']

        sources[name][version] = fixed

    lock['sources'] = sources

    return lock


if __name__ == '__main__':

    lockFile = sys.argv[1]
    newSourceFile = sys.argv[2]

    with open(lockFile, "r") as f:
        lock = json.load(f)

    with open(newSourceFile, "r") as f:
        newSource = json.load(f)

    fixed = replace_root_sources(lock, newSource)

    with open(lockFile, "w") as f:
        json.dump(fixed, f, indent=2, sort_keys=True)
