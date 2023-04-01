import os
import sys
import socket
import subprocess
import time
import tempfile
import json
import dateutil.parser
import urllib.request
from pathlib import Path

import certifi
from packaging.requirements import Requirement
from packaging.utils import (
    canonicalize_name,
)


def get_max_date(args):
    try:
        return int(args["pypiSnapshotDate"])
    except ValueError:
        return dateutil.parser.parse(args["pypiSnapshotDate"])


def get_free_port():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind(("", 0))
    port = sock.getsockname()[1]
    sock.close()
    return port


def start_mitmproxy(args, home, port):
    proc = subprocess.Popen(
        [
            args["mitmProxy"],
            "--listen-port",
            str(port),
            "--quiet",
            "--anticache",
            "--ignore-hosts",
            ".*files.pythonhosted.org.*",
            "--script",
            args["filterPypiResponsesScript"],
        ],
        stdout=sys.stderr,
        stderr=sys.stderr,
        env={"pypiSnapshotDate": args["pypiSnapshotDate"], "HOME": home},
    )
    return proc


def wait_for_proxy(proxy_port):
    timeout = time.time() + 60 * 5
    req = urllib.request.Request("http://pypi.org")
    req.set_proxy(f"127.0.0.1:{proxy_port}", "http")

    while time.time() < timeout:
        try:
            res = urllib.request.urlopen(req, None, 5)
            if res.status < 400:
                break
        except urllib.error.URLError:
            pass
        finally:
            time.sleep(1)


# as we only proxy *some* calls, we need to combine upstream
# ca certificates and the one from mitm proxy
def generate_ca_bundle(home, path):
    path = home / path
    with open(home / ".mitmproxy/mitmproxy-ca-cert.pem", "r") as f:
        mitmproxy_cacert = f.read()
    with open(certifi.where(), "r") as f:
        certifi_cacert = f.read()
    with open(path, "w") as f:
        f.write(mitmproxy_cacert)
        f.write("\n")
        f.write(certifi_cacert)
    return path


def process_dependencies(report):
    """
    Pre-process pips report.json for easier consumation by nix.
    We extract name, version, url and hash of the source distribution or
    wheel. We also preprocess requirements and their environment markers to
    the effective, platform-specific dependencies of each package. This makes
    heavy use of `packaging` which is hard to impossible to re-implement
    correctly in nix.
    """
    packages = dict()
    package_names = [
        canonicalize_name(install["metadata"]["name"])
        for install in report["install"]  # noqa: 501
    ]
    for install in report["install"]:
        metadata = install["metadata"]
        name = canonicalize_name(metadata["name"])
        version = metadata["version"]

        download_info = install["download_info"]
        url = download_info["url"]
        hash = (
            download_info.get("archive_info", {}).get("hash", "").split("=", 1)
        )  # noqa: 501
        sha256 = hash[1] if hash[0] == "sha256" else None

        dependencies = set()
        for requirement in map(Requirement, metadata.get("requires_dist", [])):
            # Correctly resolving this requirements with metadata only would
            # require us to parse and evaluate "extra" markers. This is tricky
            # as we would need to reconstruct the dependency tree and
            # evaluate from the root down, as the set of "extras" for a given
            # node is only known after we know whether its parent is optional
            # or not.
            # We assume that pip resolved them correctly already, so we just
            # include a requirement whenever it's included in the report.
            req_name = canonicalize_name(requirement.name)
            if req_name in package_names:
                dependencies.add(req_name)

        packages[name] = dict(
            url=url,
            version=version,
            sha256=sha256,
            dependencies=list(dependencies),
        )
    return packages


if __name__ == "__main__":
    with open(sys.argv[1], "r") as f:
        args = json.load(f)

    with tempfile.TemporaryDirectory() as home:
        home = Path(home)

        print(
            f"selected maximum release date for python packages: {get_max_date(args)}",  # noqa: E501
            file=sys.stderr,
        )
        proxy_port = get_free_port()

        proxy = start_mitmproxy(args, home, proxy_port)
        wait_for_proxy(proxy_port)
        cafile = generate_ca_bundle(home, ".ca-cert.pem")

        venv_path = (home / ".venv").absolute()
        subprocess.run([sys.executable, "-m", "venv", venv_path], check=True)
        subprocess.run(
            [
                f"{venv_path}/bin/pip",
                "install",
                "--upgrade",
                f"pip=={args['pipVersion']}",
            ],
            check=True,
            stdout=sys.stderr,
            stderr=sys.stderr,
        )

        flags = args["pipFlags"] + [
            "--proxy",
            f"https://localhost:{proxy_port}",
            "--progress-bar",
            "off",
            "--cert",
            cafile,
            "--report",
            str(home / "report.json"),
        ]
        for req in args["requirementsList"]:
            if req:
                flags.append(req)
        for req in args["requirementsFiles"]:
            if req:
                flags += ["-r", req]

        subprocess.run(
            [
                f"{venv_path}/bin/pip",
                "install",
                "--dry-run",
                "--ignore-installed",
                # "--use-feature=fast-deps",
                *flags,
            ],
            check=True,
            stdout=sys.stderr,
            stderr=sys.stderr,
        )
        proxy.kill()

        with open(home / "report.json", "r") as f:
            report = json.load(f)
        with open(os.getenv("out"), "w") as f:
            packages = process_dependencies(report)
            json.dump(packages, f, indent=2, sort_keys=True)
