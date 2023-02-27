import os
import socket
import ssl
import subprocess
import time
import dateutil.parser
import urllib.request
from pathlib import Path

import certifi
from packaging.utils import canonicalize_name, parse_sdist_filename, parse_wheel_filename


HOME = Path(os.getcwd())
OUT = Path(os.getenv("out"))
PYTHON_BIN = os.getenv("pythonBin")
PYTHON_WITH_MITM_PROXY = os.getenv("pythonWithMitmproxy")
FILTER_PYPI_RESPONSE_SCRIPTS = os.getenv("filterPypiResponsesScript")
PIP_VERSION = os.getenv("pipVersion")
PIP_FLAGS = os.getenv('pipFlags')
ONLY_BINARY_FLAGS = os.getenv('onlyBinaryFlags')
REQUIREMENTS_LIST = os.getenv('requirementsList')
REQUIREMENTS_FLAGS = os.getenv('requirementsFlags')

def get_max_date():
    try:
        return int(os.getenv("MAX_DATE"))
    except ValueError:
        return dateutil.parser.parse(os.getenv("MAX_DATE"))


def get_free_port():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind(("", 0))
    port = sock.getsockname()[1]
    sock.close()
    return port


def start_mitmproxy(port):
    proc = subprocess.Popen(
        [
            f"{PYTHON_WITH_MITM_PROXY}/bin/mitmdump",
            "--listen-port", str(port),
            "--ignore-hosts", ".*files.pythonhosted.org.*",
            "--script", FILTER_PYPI_RESPONSE_SCRIPTS
        ],
        env = {
            "MAX_DATE": os.getenv('MAX_DATE'),
            "HOME": HOME
        }
    )
    return proc


def wait_for_proxy(proxy_port, cafile):
    timeout = time.time() + 60 * 5
    req = urllib.request.Request('https://pypi.org')
    req.set_proxy(f'127.0.0.1:{proxy_port}', 'http')
    req.set_proxy(f'127.0.0.1:{proxy_port}', 'https')

    context = ssl.create_default_context(cafile=cafile)
    while time.time() < timeout:
        try:
            res = urllib.request.urlopen(req, None, 5, context=context)
            if res.status < 400:
                break
        except urllib.error.URLError as e:
            pass
        finally:
            time.sleep(1)


# as we only proxy *some* calls, we need to combine upstream
# ca certificates and the one from mitm proxy
def generate_ca_bundle(path):
     with open(HOME / ".mitmproxy/mitmproxy-ca-cert.pem", "r") as f:
         mitmproxy_cacert = f.read()
     with open(certifi.where(), "r") as f:
         certifi_cacert = f.read()
     with open(path, "w") as f:
         f.write(mitmproxy_cacert)
         f.write("\n")
         f.write(certifi_cacert)
     return path

def create_venv(path):
    subprocess.run([PYTHON_BIN, '-m', 'venv', path], check=True)


def pip(venv_path, *args):
    subprocess.run([f"{venv_path}/bin/pip", *args], check=True)


if __name__ == '__main__':
    OUT.mkdir()
    dist_path = OUT / "dist"
    names_path = OUT / "names"
    dist_path.mkdir()
    names_path.mkdir()

    print(f"selected maximum release date for python packages: {get_max_date()}")
    proxy_port = get_free_port()

    proxy = start_mitmproxy(proxy_port)

    venv_path = Path('.venv').absolute()
    create_venv(venv_path)
    pip(venv_path, 'install', '--upgrade', f'pip=={PIP_VERSION}')

    cafile = generate_ca_bundle(HOME / ".ca-cert.pem")
    wait_for_proxy(proxy_port, cafile)

    optional_flags = [PIP_FLAGS, ONLY_BINARY_FLAGS, REQUIREMENTS_LIST, REQUIREMENTS_FLAGS]
    optional_flags = " ".join(filter(None, optional_flags)).split(" ")
    pip(
        venv_path,
         'download',
        '--no-cache',
        '--dest', dist_path,
        '--progress-bar', 'off',
        '--proxy', f'https://localhost:{proxy_port}',
        '--cert', cafile,
        *optional_flags
    )

    proxy.kill()

    for dist_file in dist_path.iterdir():
        if dist_file.suffix == '.whl':
            name = parse_wheel_filename(dist_file.name)[0]
        else:
            name = parse_sdist_filename(dist_file.name)[0]
        pname = canonicalize_name(name)
        name_path = names_path / pname
        print(f'creating link {name_path} -> {dist_file}')
        name_path.mkdir()
        (name_path / dist_file.name).symlink_to(f"../../dist/{dist_file.name}")
