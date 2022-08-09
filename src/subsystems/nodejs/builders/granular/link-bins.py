import json
import os
import pathlib


with open('package.json') as f:
  package_json = json.load(f)

out = os.environ.get('out')

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
      name = package_json['name'].split('/')[-1]
      link(name, bin)

    else:
      for name, relpath in bin.items():
        link(name, relpath)

# symlink current packages executables to $nodeModules/.bin
symlink_bin(f'{out}/lib/node_modules/.bin/', package_json)
# symlink current packages executables to $out/bin
symlink_bin(f'{out}/bin/', package_json)
