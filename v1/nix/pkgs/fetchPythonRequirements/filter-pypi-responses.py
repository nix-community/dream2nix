"""
This script is part of fetchPythonRequirements
It is meant to be used with mitmproxy via `--script`
It will filter api repsonses from the pypi.org api (used by pip),
to only contain files with release date < MAX_DATE

For retrieving the release dates for files, it uses the pypi.org json api
It has to do one extra api request for each queried package name
"""
import json
import os
import sys
import ssl
from urllib.request import Request, urlopen
from pathlib import Path
import dateutil.parser
import gzip

from mitmproxy import http


"""
Query the pypi json api to get timestamps for all release files of the given pname.
return all file names which are newer than the given timestamp
"""
def get_files_to_hide(pname, max_ts):
    ca_file = Path(os.getenv('HOME')) / ".ca-cert.pem"
    context = ssl.create_default_context(cafile=ca_file)
    if not ca_file.exists():
        print("mitmproxy ca not found")
        sys.exit(1)

    # query the api
    url = f"https://pypi.org/pypi/{pname}/json"
    req = Request(url)
    req.add_header('Accept-Encoding', 'gzip')
    with urlopen(req, context=context) as response:
        content = gzip.decompress(response.read())
        resp = json.loads(content)

    # collect files to hide
    files = set()
    for ver, releases in resp['releases'].items():
        for release in releases:
            ts = dateutil.parser.parse(release['upload_time']).timestamp()
            if ts > max_ts:
                files.add(release['filename'])
    return files


# accept unix timestamp or human readable format
try:
    max_ts = int(os.getenv("MAX_DATE"))
except ValueError:
    max_date = dateutil.parser.parse(os.getenv("MAX_DATE"))
    max_ts = max_date.timestamp()


"""
Response format:
{
  "files": [
    {
      "filename": "pip-0.2.tar.gz",
      "hashes": {
        "sha256": "88bb8d029e1bf4acd0e04d300104b7440086f94cc1ce1c5c3c31e3293aee1f81"
      },
      "requires-python": null,
      "url": "https://files.pythonhosted.org/packages/3d/9d/1e313763bdfb6a48977b65829c6ce2a43eaae29ea2f907c8bbef024a7219/pip-0.2.tar.gz",
      "yanked": false
    },
    {
      "filename": "pip-0.2.1.tar.gz",
      "hashes": {
        "sha256": "83522005c1266cc2de97e65072ff7554ac0f30ad369c3b02ff3a764b962048da"
      },
      "requires-python": null,
      "url": "https://files.pythonhosted.org/packages/18/ad/c0fe6cdfe1643a19ef027c7168572dac6283b80a384ddf21b75b921877da/pip-0.2.1.tar.gz",
      "yanked": false
    }
}
"""
def response(flow: http.HTTPFlow) -> None:
    if not "/simple/" in flow.request.url:
        return
    pname = flow.request.url.strip('/').split('/')[-1]
    badFiles = get_files_to_hide(pname, max_ts)
    keepFile = lambda file: file['filename'] not in badFiles
    data = json.loads(flow.response.text)
    if badFiles:
        print(f"removing the following files form the API response:\n  {badFiles}")
        data['files'] = list(filter(keepFile, data['files']))
    flow.response.text = json.dumps(data)
