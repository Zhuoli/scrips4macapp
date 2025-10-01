#!/usr/bin/env python3
"""Simple web server that exposes shell scripts via a browser UI."""

from __future__ import annotations

import argparse
import json
import subprocess
import uuid
from collections import OrderedDict
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse
from threading import Lock

ROOT = Path(__file__).resolve().parent
SCRIPTS_DIR = ROOT / "scripts"
STATIC_DIR = ROOT / "static"

SUPPORTED_SCRIPT_TYPES = {
    ".sh": {
        "label": "Shell Script",
        "runner": ["/bin/bash"],
    },
    ".py": {
        "label": "Python Script",
        "runner": ["python3"],
    },
}

RESULT_HISTORY_LIMIT = 50
_RESULTS: "OrderedDict[str, dict[str, str]]" = OrderedDict()
_RESULT_LOCK = Lock()


def list_scripts() -> list[dict[str, str]]:
    scripts: list[dict[str, str]] = []
    for entry in SCRIPTS_DIR.iterdir():
        if not entry.is_file():
            continue
        metadata = SUPPORTED_SCRIPT_TYPES.get(entry.suffix.lower())
        if metadata is None:
            continue
        scripts.append({
            "name": entry.name,
            "type": metadata["label"],
        })
    scripts.sort(key=lambda item: item["name"].lower())
    return scripts


def _resolve_script(name: str) -> tuple[Path, list[str], str]:
    script_path = (SCRIPTS_DIR / name).resolve()
    try:
        script_path.relative_to(SCRIPTS_DIR.resolve())
    except ValueError as exc:
        raise ValueError("invalid script path") from exc

    if not script_path.exists() or not script_path.is_file():
        raise FileNotFoundError(f"script '{name}' not found")

    metadata = SUPPORTED_SCRIPT_TYPES.get(script_path.suffix.lower())
    if metadata is None:
        raise ValueError("unsupported script type")

    return script_path, list(metadata["runner"]), metadata["label"]


def _store_result(script_name: str, stdout: str, stderr: str) -> tuple[str, str]:
    parts: list[str] = []
    stdout = stdout or ""
    stderr = stderr or ""
    if stdout:
        parts.append(stdout.rstrip("\n"))
    if stderr:
        if parts:
            parts.append("")
        parts.append("[stderr]")
        parts.append(stderr.rstrip("\n"))
    combined = "\n".join(parts) if parts else "(no output)"
    result_id = uuid.uuid4().hex
    with _RESULT_LOCK:
        _RESULTS[result_id] = {"script": script_name, "content": combined}
        while len(_RESULTS) > RESULT_HISTORY_LIMIT:
            _RESULTS.popitem(last=False)
    return result_id, combined


def _get_result(result_id: str) -> dict[str, str] | None:
    with _RESULT_LOCK:
        record = _RESULTS.get(result_id)
        if record is None:
            return None
        return dict(record)


def run_script(name: str, arg: str) -> dict[str, object]:
    script_path, runner, script_type = _resolve_script(name)

    command = runner + [str(script_path)]
    command.append(arg)

    proc = subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
    )
    download_id, combined_output = _store_result(name, proc.stdout, proc.stderr)
    return {
        "exit_code": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
        "download_id": download_id,
        "script": name,
        "script_type": script_type,
        "combined_output": combined_output,
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
        elif path.startswith("/api/output/"):
            result_id = path[len("/api/output/") :]
            self._serve_result_download(result_id)
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

        if not isinstance(script_name, str):
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
            self.send_error(HTTPStatus.BAD_REQUEST, "Invalid script")
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

    def _serve_result_download(self, result_id: str) -> None:
        if not result_id:
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing result id")
            return

        record = _get_result(result_id)
        if record is None:
            self.send_error(HTTPStatus.NOT_FOUND, "Result not found")
            return

        data = record["content"].encode("utf-8")
        filename = self._safe_filename(record["script"], result_id)

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
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

    @staticmethod
    def _safe_filename(script_name: str, result_id: str) -> str:
        base = Path(script_name).stem or "output"
        safe_base = "".join(ch for ch in base if ch.isalnum() or ch in {"-", "_"}) or "output"
        return f"{safe_base}-{result_id}.log"

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
