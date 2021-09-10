from glob import glob
import base64
import hashlib
import json
import sys


def main():
  direcotry = sys.argv[1]
  output_file = sys.argv[2]

  packages = {}

  # loop over the downloaded files and compute:
  #  - url
  #  - sha256
  #  - format (sdist/wheel)
  for path in list(glob(direcotry + '/*')):
    _, _, file = path.rpartition('/')

    print(f"processing file: {file}")

    # example: charset_normalizer-2.0.4-py3-none-any.whl
    if file.endswith('.whl'):
      format = 'wheel'
      pname, _, pyver, _, _ = file.split('-')
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
  generic_lock = dict(
    sources={},
    generic={
      "buildSystem": "python",
      "buildSystemFormatVersion": 1,
      "producedBy": "translator-external-pip",

      # This translator is not aware of the exact dependency graph.
      # This restricts us to use a single derivation builder later,
      # which will install all packages at once
      "dependencyGraph": None,
    },
    buildSystem={
      "pythonAttr": f"python{sys.version_info.major}{sys.version_info.minor}",
      "sourceFormats":
        {pname: data['format'] for pname, data in packages.items()}
    }
  )

  # populate sources of generic lock
  for pname, data in packages.items():
    generic_lock['sources'][pname] = dict(
      url=data['url'],
      hash=data['sha256'],
      type='fetchurl',
    )

  # dump generic lock to stdout (json)
  with open(output_file, 'w') as lock:
    json.dump(generic_lock, lock, indent=2)


if __name__ == "__main__":
  main()
