import argparse
from glob import glob
import json
import os
from pathlib import Path
from typing import List
from urllib.parse import urljoin

from requests import Response, Session


def read_json_file(path):
    with open(path) as f:
        return json.load(f)


def get_password_requests() -> List[str]:
    requests = []
    for user in read_json_file("./passwords.json"):
        var = user["pass_env"]
        uname = user["name"]
        if not (password := os.environ.get(var)):
            raise ValueError(f"{var} env var expected to hold password for {uname}")
        requests.append(
            {
                "order": 100,
                "method": "post",
                "url": f"_security/user/{uname}/_password",
                "body": {"password": password},
            }
        )
    return requests


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    file_xor_password = parser.add_mutually_exclusive_group()
    file_xor_password.add_argument(
        "--passwords",
        "-p",
        action="store_true",
        required=False,
        help="Only set passwords from passwords.json",
    )
    file_xor_password.add_argument(
        "--single-file",
        "-f",
        type=Path,
        required=False,
        help="Send request for a single file. For debug purposes. Does not work for "
        "passwords.json.",
    )

    args = parser.parse_args()

    ELASTIC_HOST = os.environ.get("ELASTIC_HOST")
    ELASTIC_PASSWORD = os.environ.get("ELASTIC_PASSWORD")

    if not ELASTIC_HOST:
        raise ValueError("ELASTIC_HOST env var not set.")

    if not ELASTIC_PASSWORD:
        raise ValueError("ELASTIC_PASSWORD env var not set.")

    sess = Session()
    sess.auth = ("elastic", ELASTIC_PASSWORD)

    if args.single_file:
        requests = [read_json_file(args.single_file)]
    elif args.passwords:
        requests = get_password_requests()
    else:
        requests = get_password_requests()
        requests += [read_json_file(p) for p in glob("./resources/**/*.json")]

    requests = sorted(requests, key=lambda r: r["order"])

    for res in requests:
        method = res["method"]
        url = urljoin(ELASTIC_HOST, res["url"])
        print(f"[{method}] {url}")
        func = getattr(sess, method)
        resp: Response = func(url, json=res["body"])
        print(resp.status_code)
        if not resp.ok:
            print(resp.json())
            raise Exception("Failed to create resource.")
