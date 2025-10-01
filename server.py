#!/usr/bin/env python3
"""Simple web server that exposes shell scripts via a browser UI."""

from __future__ import annotations

import argparse
import json
import subprocess
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
SCRIPTS_DIR = ROOT / "scripts"
STATIC_DIR = ROOT / "static"


def list_scripts() -> list[str]:
    return sorted(script.name for script in SCRIPTS_DIR.glob("*.sh"))


def run_script(name: str, arg: str) -> dict[str, object]:
    script_path = (SCRIPTS_DIR / name).resolve()
    try:
        script_path.relative_to(SCRIPTS_DIR.resolve())
    except ValueError as exc:
        raise ValueError("invalid script path") from exc

    if not script_path.exists() or not script_path.is_file():
        raise FileNotFoundError(f"script '{name}' not found")

    proc = subprocess.run(
        ["/bin/bash", str(script_path), arg],
        capture_output=True,
        text=True,
        check=False,
    )
    return {
        "exit_code": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }


class ScriptRunnerHandler(BaseHTTPRequestHandler):
    server_version = "ScriptRunner/1.0"

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler requirement
        parsed = urlparse(self.path)
        path = parsed.path
        if path in {"/", "", "/index.html"}:
            self._serve_file(STATIC_DIR / "index.html", "text/html; charset=utf-8")
        elif path == "/api/scripts":
            self._write_json({"scripts": list_scripts()})
        elif path.startswith("/static/"):
            rel = path[len("/static/") :]
            target = (STATIC_DIR / rel).resolve()
            if STATIC_DIR.resolve() in target.parents or target == STATIC_DIR.resolve():
                self._serve_file(target)
            else:
                self.send_error(HTTPStatus.NOT_FOUND)
        else:
            self.send_error(HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler requirement
        parsed = urlparse(self.path)
        if parsed.path != "/api/run":
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_error(HTTPStatus.BAD_REQUEST, "Invalid Content-Length")
            return

        payload = self.rfile.read(content_length)
        try:
            body = json.loads(payload)
        except json.JSONDecodeError:
            self.send_error(HTTPStatus.BAD_REQUEST, "Body must be JSON")
            return

        script_name = body.get("script")
        argument = body.get("argument", "")

        if not isinstance(script_name, str) or script_name not in list_scripts():
            self.send_error(HTTPStatus.BAD_REQUEST, "Unknown script")
            return
        if not isinstance(argument, str):
            self.send_error(HTTPStatus.BAD_REQUEST, "Argument must be a string")
            return

        try:
            result = run_script(script_name, argument)
        except FileNotFoundError:
            self.send_error(HTTPStatus.BAD_REQUEST, "Script not found")
            return
        except ValueError:
            self.send_error(HTTPStatus.BAD_REQUEST, "Invalid script name")
            return
        except subprocess.SubprocessError as exc:
            self.send_error(HTTPStatus.INTERNAL_SERVER_ERROR, str(exc))
            return

        self._write_json(result)

    def log_message(self, fmt: str, *args) -> None:  # noqa: D401
        """Suppress default stdout logging to keep console clean."""
        return

    def _serve_file(self, path: Path, content_type: str | None = None) -> None:
        try:
            data = path.read_bytes()
        except FileNotFoundError:
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        if content_type is None:
            content_type = self._guess_content_type(path)

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    @staticmethod
    def _guess_content_type(path: Path) -> str:
        mapping = {
            ".css": "text/css; charset=utf-8",
            ".js": "application/javascript; charset=utf-8",
            ".html": "text/html; charset=utf-8",
            ".json": "application/json; charset=utf-8",
        }
        return mapping.get(path.suffix, "application/octet-stream")

    def _write_json(self, payload: dict[str, object]) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=8000, help="Port to listen on (default: 8000)")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    server_address = (args.host, args.port)
    httpd = ThreadingHTTPServer(server_address, ScriptRunnerHandler)
    print(f"Serving on http://{args.host}:{args.port}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
