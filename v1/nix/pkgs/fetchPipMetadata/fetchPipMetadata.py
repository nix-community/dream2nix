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
    timeout = time.time() + 10
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


def evaluate_extras(req, extras, env):
    if not extras:
        return req.marker.evaluate({**env, "extra": ""})
    else:
        return any({req.marker.evaluate({**env, "extra": e}) for e in extras})


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
    installs_by_name = dict()
    env = report["environment"]
    roots = filter(lambda p: p.get("requested", False), report["install"])
    for install in report["install"]:
        name = canonicalize_name(install["metadata"]["name"])
        installs_by_name[name] = install

        download_info = install["download_info"]
        hash = (
            download_info.get("archive_info", {})
            .get("hash", "")
            .split("=", 1)  # noqa: 501
        )
        sha256 = hash[1] if hash[0] == "sha256" else None
        packages[name] = dict(
            url=download_info["url"],
            version=install["metadata"]["version"],
            sha256=sha256,
            dependencies=[],
        )

    def walker(root, seen, extras):
        root_name = canonicalize_name(root["metadata"]["name"])

        if root_name in seen:
            print(f"cycle detected: {root_name} ({' '.join(seen)})")
            sys.exit(1)

        # we copy "seen", because we want to track cycles per tree-branch
        # and the original would be visible for all branches.
        seen = seen.copy()
        seen.append(root_name)

        reqs = map(Requirement, root["metadata"].get("requires_dist", []))
        for req in reqs:
            if (not req.marker) or evaluate_extras(req, extras, env):
                req_name = canonicalize_name(req.name)
                if req_name not in packages[root_name]["dependencies"]:
                    packages[root_name]["dependencies"].append(req_name)
                walker(installs_by_name[req_name], seen, req.extras)

    for root in roots:
        walker(root, list(), root.get("requested_extras", set()))
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
