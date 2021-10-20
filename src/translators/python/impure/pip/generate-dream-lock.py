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
      pname, _, _ = file.rpartition('-')
      pyver = 'source'

    url = f"https://files.pythonhosted.org/packages/{pyver}/{pname[0]}/{pname}/{file}"

    with open(path, 'rb') as f:
      sha256 = f"sha256-{base64.b64encode(hashlib.sha256(f.read()).digest()).decode()}"

    packages[pname] = dict(
      url=url,
      sha256=sha256,
      format=format
    )

  # create generic lock
  # This translator is not aware of the exact dependency graph.
  # This restricts us to use a single derivation builder later,
  # which will install all packages at once
  dream_lock = dict(
    sources={},
    generic={
      "buildSystem": "python",
      "mainPackage": os.environ.get('MAIN'),

      "sourcesCombinedHash": None,
    },
    buildSystem={
      "application": jsonInput['application'],
      "pythonAttr": f"python{sys.version_info.major}{sys.version_info.minor}",
      "sourceFormats":
        {pname: data['format'] for pname, data in packages.items()}
    }
  )

  # populate sources of generic lock
  for pname, data in packages.items():
    dream_lock['sources'][pname] = dict(
      url=data['url'],
      hash=data['sha256'],
      type='fetchurl',
    )

  # dump generic lock to stdout (json)
  print(jsonInput['outputFile'])
  with open(jsonInput['outputFile'], 'w') as lock:
    json.dump(dream_lock, lock, indent=2)


if __name__ == "__main__":
  main()
