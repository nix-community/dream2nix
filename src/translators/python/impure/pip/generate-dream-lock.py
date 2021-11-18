from glob import glob
import base64
import hashlib
import json
import os
import sys
import urllib.request


def main():
  directory = sys.argv[1]

  with open(sys.argv[2]) as f:
    jsonInput = json.load(f)

  packages = {}

  # loop over the downloaded files and compute:
  #  - url
  #  - sha256
  #  - format (sdist/wheel)
  for path in list(glob(directory + '/*')):
    _, _, file = path.rpartition('/')

    print(f"processing file: {file}")

    # example: charset_normalizer-2.0.4-py3-none-any.whl
    if file.endswith('.whl'):
      format = 'wheel'
      pname, version, _, _, _ = file.split('-')
      with urllib.request.urlopen(f'https://pypi.org/pypi/{pname}/json') as f:
        releasesForVersion = json.load(f)['releases'][version]
      release = next(r for r in releasesForVersion if r['filename'] == file)
      pyver = release['python_version']

    # example: requests-2.26.0.tar.gz
    else:
      format = 'sdist'
      pname, version, _ = file.rpartition('-')
      pyver = 'source'

    url = f"https://files.pythonhosted.org/packages/{pyver}/{pname[0]}/{pname}/{file}"

    with open(path, 'rb') as f:
      sha256 = f"sha256-{base64.b64encode(hashlib.sha256(f.read()).digest()).decode()}"

    packages[pname] = dict(
      version=version,
      url=url,
      sha256=sha256,
      format=format
    )

  # create dream lock
  # This translator is not aware of the exact dependency graph.
  # This restricts us to use a single derivation builder later,
  # which will install all packages at once
  dream_lock = dict(
    sources={},
    _generic={
      "subsystem": "python",
      "mainPackageName": os.environ.get('NAME'),
      "mainPackageVersion": os.environ.get('VERSION'),

      "sourcesAggregatedHash": None,
    },
    _subsystem={
      "application": jsonInput['application'],
      "pythonAttr": f"python{sys.version_info.major}{sys.version_info.minor}",
      "sourceFormats":
        {pname: data['format'] for pname, data in packages.items()}
    }
  )

  # populate sources of dream lock
  for pname, data in packages.items():
    if pname not in dream_lock['sources']:
      dream_lock['sources'][pname] = {}
    dream_lock['sources'][pname][data['version']] = dict(
      url=data['url'],
      hash=data['sha256'],
      type='http',
    )

  # dump dream lock to $ouputFile
  print(jsonInput['outputFile'])
  with open(jsonInput['outputFile'], 'w') as lock:
    json.dump(dream_lock, lock, indent=2)


if __name__ == "__main__":
  main()
