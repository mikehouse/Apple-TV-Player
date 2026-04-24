#!/usr/bin/env python3

import argparse
import json
import logging
import mimetypes
import re
import shutil
import subprocess
import threading
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


PROJECT_ROOT = Path(__file__).resolve().parent
SAFE_SEGMENT = re.compile(r"^[A-Za-z0-9._-]+$")
UUID_PATTERN = re.compile(r"^[0-9A-Fa-f-]+$")

logger = logging.getLogger("server")

DB_FILE = "default.store"
DB_SHM_FILE = "default.store-shm"
DB_WAL_FILE = "default.store-wal"
DB_FILES = (DB_FILE, DB_SHM_FILE, DB_WAL_FILE)


def is_safe_segment(value: str) -> bool:
    return bool(value) and bool(SAFE_SEGMENT.fullmatch(value))


def resolve_file(*parts: str) -> Path | None:
    candidate = PROJECT_ROOT.joinpath(*parts).resolve()
    try:
        candidate.relative_to(PROJECT_ROOT)
    except ValueError:
        return None
    return candidate if candidate.is_file() else None


class PlaylistRequestHandler(BaseHTTPRequestHandler):
    server_version = "PlaylistHTTP/1.0"

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        params = {key: values[-1] for key, values in parse_qs(parsed.query).items() if values}

        routes = {
            "/config": self.handle_config,
            "/database-config": self.handle_database_config,
            "/playlist": self.handle_playlist,
            "/playlist-logo": self.handle_playlist_logo,
            "/playlist-tvg": self.handle_playlist_tvg,
            "/playlist-images": self.handle_playlist_images,
            "/set-appearance": self.handle_set_appearance,
            "/shutdown": self.handle_shutdown,
            "/copy-database": self.handle_copy_database,
            "/copy-snapshot": self.handle_copy_snapshot,
        }

        handler = routes.get(parsed.path)
        if handler is None:
            self.send_error(HTTPStatus.NOT_FOUND, "Endpoint not found")
            return

        handler(params)

    def do_HEAD(self) -> None:
        self.send_error(HTTPStatus.METHOD_NOT_ALLOWED, "Use GET")

    def handle_config(self, params: dict[str, str]) -> None:
        lang = params.get("lang")
        if not lang or not is_safe_segment(lang):
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing or invalid lang")
            return

        config_path = resolve_file("playlists", "configs", lang, "config.json")
        if config_path is None:
            self.send_error(HTTPStatus.NOT_FOUND, "Config not found")
            return

        payload = config_path.read_text(encoding="utf-8").replace("${port}", str(self.server.server_port))
        self.send_text(payload, "application/json; charset=utf-8")

    def handle_database_config(self, params: dict[str, str]) -> None:
        lang = params.get("lang")
        if not lang or not is_safe_segment(lang):
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing or invalid lang")
            return

        db_path = resolve_file("playlists", "database", lang, DB_FILE)
        if db_path is None:
            self.send_error(HTTPStatus.NOT_FOUND, "Database not found")
            return

        self.send_json({"path": str(db_path)})

    def handle_playlist(self, params: dict[str, str]) -> None:
        name = params.get("name")
        lang = params.get("lang")
        if not name or not is_safe_segment(name):
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing or invalid name")
            return
        if lang and not is_safe_segment(lang):
            self.send_error(HTTPStatus.BAD_REQUEST, "Invalid lang")
            return

        candidates = []
        if lang:
            candidates.append(("playlists", name, lang, "playlist.m3u"))
        candidates.append(("playlists", name, "playlist.m3u"))
        self.send_first_existing(
            candidates,
            content_type="application/x-mpegURL; charset=utf-8",
            not_found_message="Playlist not found",
        )

    def handle_playlist_logo(self, params: dict[str, str]) -> None:
        name = params.get("name")
        if not name or not is_safe_segment(name):
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing or invalid name")
            return

        logo_path = resolve_file("playlists", name, "logo.png")
        if logo_path is None:
            self.send_error(HTTPStatus.NOT_FOUND, "Playlist logo not found")
            return

        self.send_file(logo_path, "image/png")

    def handle_playlist_tvg(self, params: dict[str, str]) -> None:
        name = params.get("name")
        lang = params.get("lang")
        if not name or not is_safe_segment(name):
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing or invalid name")
            return
        if lang and not is_safe_segment(lang):
            self.send_error(HTTPStatus.BAD_REQUEST, "Invalid lang")
            return

        candidates = []
        if lang:
            candidates.append(("playlists", name, "tvg", lang, "tvg.xml"))
        candidates.append(("playlists", name, "tvg", "tvg.xml"))
        self.send_first_existing(
            candidates,
            content_type="application/xml; charset=utf-8",
            not_found_message="TV guide not found",
        )

    def handle_playlist_images(self, params: dict[str, str]) -> None:
        name = params.get("name")
        if not name or not is_safe_segment(name):
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing or invalid name")
            return

        archive_path = resolve_file("playlists", name, "images", "Archive.zip")
        if archive_path is None:
            self.send_error(HTTPStatus.NOT_FOUND, "Playlist images not found")
            return

        self.send_file(archive_path, "application/zip")

    def handle_set_appearance(self, params: dict[str, str]) -> None:
        mode = params.get("mode", "")
        uuid = params.get("uuid", "")

        if mode and uuid:
            command = ["xcrun", "simctl", "ui", uuid, "appearance", mode]
            try:
                result = subprocess.run(
                    command,
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=30,
                )
                print(
                    f"set-appearance command finished with exit code {result.returncode}: {' '.join(command)}"
                )
                if result.stdout.strip():
                    print(result.stdout.strip())
                if result.stderr.strip():
                    print(result.stderr.strip())
            except Exception as exc:
                print(f"set-appearance command failed: {' '.join(command)}")
                print(str(exc))
        else:
            print("set-appearance skipped: missing mode or uuid")

        self.send_text("OK\n", "text/plain; charset=utf-8")

    def handle_shutdown(self, params: dict[str, str]) -> None:
        self.send_text("Server is shutting down.\n", "text/plain; charset=utf-8")
        threading.Thread(target=self.server.shutdown, daemon=True).start()

    def handle_copy_database(self, params: dict[str, str]) -> None:
        uuid = params.get("uuid", "")
        lang = params.get("lang", "")

        if not uuid or not UUID_PATTERN.fullmatch(uuid):
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing or invalid uuid")
            return
        if not lang or not is_safe_segment(lang):
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing or invalid lang")
            return

        home = Path.home()
        app_containers = home / "Library" / "Developer" / "CoreSimulator" / "Devices" / uuid / "data" / "Containers" / "Data" / "Application"

        if not app_containers.is_dir():
            msg = f"Application containers directory not found: {app_containers}"
            logger.error(msg)
            self.send_error(HTTPStatus.NOT_FOUND, msg)
            return

        # Search for default.store inside all sandbox UUIDs
        expected_suffix = Path("Library") / "Caches" / DB_FILE

        # Search for default.store inside all sandbox UUIDs
        found: list[Path] = []

        for sandbox_dir in app_containers.iterdir():
            if not sandbox_dir.is_dir():
                continue
            # Search recursively – the database may be in Library/Caches,
            # Library/Application Support, or another subfolder.
            for candidate in sandbox_dir.rglob(DB_FILE):
                if not candidate.is_file():
                    continue
                # Validate path: …/Application/<SANDBOX_UUID>/Library/*/default.store
                try:
                    relative = candidate.relative_to(sandbox_dir)
                except ValueError:
                    continue
                parts = relative.parts
                # Expect at least: ("Library", <subfolder…>, "default.store")
                if len(parts) >= 3 and parts[0] == "Library":
                    found.append(candidate)

        if len(found) == 0:
            msg = f"No database ({DB_FILE}) found under {app_containers}"
            logger.error(msg)
            self.send_error(HTTPStatus.NOT_FOUND, msg)
            return

        if len(found) > 1:
            msg = (
                f"Found {len(found)} databases under {app_containers}, "
                "expected exactly 1. Cannot determine which app is correct."
            )
            logger.error(msg)
            self.send_error(HTTPStatus.CONFLICT, msg)
            return

        db_path = found[0]
        db_dir = db_path.parent

        # Verify all three database files exist
        missing = [name for name in DB_FILES if not (db_dir / name).is_file()]
        if missing:
            msg = f"Database is incomplete. Missing files: {', '.join(missing)} in {db_dir}"
            logger.error(msg)
            self.send_error(HTTPStatus.INTERNAL_SERVER_ERROR, msg)
            return

        dest_dir = PROJECT_ROOT / "playlists" / "database" / lang
        dest_dir.mkdir(parents=True, exist_ok=True)

        # Remove existing database files if present
        for name in DB_FILES:
            existing = dest_dir / name
            if existing.exists():
                logger.info("Removing existing file: %s", existing)
                existing.unlink()

        # Copy the three database files
        for name in DB_FILES:
            src = db_dir / name
            dst = dest_dir / name
            logger.info("Copy database from %s to %s", src, dst)
            shutil.copy2(src, dst)

        logger.info("Database copied successfully for lang=%s", lang)
        self.send_text("OK\n", "text/plain; charset=utf-8")

    def handle_copy_snapshot(self, params: dict[str, str]) -> None:
        snapshot = params.get("snapshot", "")
        destination = params.get("destination", "")

        if not snapshot:
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing snapshot")
            return
        if not destination:
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing destination")
            return

        snapshot_path = Path(snapshot).expanduser()
        destination_dir = Path(destination).expanduser()

        if not snapshot_path.is_absolute():
            self.send_error(HTTPStatus.BAD_REQUEST, "Snapshot must be an absolute path")
            return
        if not destination_dir.is_absolute():
            self.send_error(HTTPStatus.BAD_REQUEST, "Destination must be an absolute path")
            return
        if snapshot_path.suffix.lower() != ".png":
            self.send_error(HTTPStatus.BAD_REQUEST, "Snapshot must be a PNG file")
            return
        if not snapshot_path.is_file():
            self.send_error(HTTPStatus.NOT_FOUND, f"Snapshot not found: {snapshot_path}")
            return
        if destination_dir.exists() and not destination_dir.is_dir():
            self.send_error(HTTPStatus.BAD_REQUEST, f"Destination is not a directory: {destination_dir}")
            return

        try:
            destination_dir.mkdir(parents=True, exist_ok=True)
        except Exception as exc:
            logger.exception("Failed to create destination directory %s", destination_dir)
            self.send_error(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"Failed to create destination directory: {exc}",
            )
            return

        target_path = destination_dir / snapshot_path.name

        try:
            logger.info("Copy snapshot from %s to directory %s", snapshot_path, destination_dir)
            shutil.copy2(snapshot_path, target_path)
        except Exception as exc:
            logger.exception("Failed to copy snapshot from %s to %s", snapshot_path, target_path)
            self.send_error(HTTPStatus.INTERNAL_SERVER_ERROR, f"Failed to copy snapshot: {exc}")
            return

        self.send_text("OK\n", "text/plain; charset=utf-8")

    def send_first_existing(
        self,
        candidates: list[tuple[str, ...]],
        *,
        content_type: str,
        not_found_message: str,
    ) -> None:
        for parts in candidates:
            file_path = resolve_file(*parts)
            if file_path is not None:
                self.send_file(file_path, content_type)
                return

        self.send_error(HTTPStatus.NOT_FOUND, not_found_message)

    def send_text(self, payload: str, content_type: str) -> None:
        self.send_bytes(payload.encode("utf-8"), content_type)

    def send_json(self, payload: dict[str, str]) -> None:
        self.send_text(json.dumps(payload), "application/json; charset=utf-8")

    def send_file(self, path: Path, content_type: str | None = None) -> None:
        payload = path.read_bytes()
        guessed_type, _ = mimetypes.guess_type(path.name)
        self.send_bytes(payload, content_type or guessed_type or "application/octet-stream")

    def send_bytes(self, payload: bytes, content_type: str) -> None:
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format: str, *args) -> None:
        print(f"{self.address_string()} - {format % args}")


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description="Serve local playlist files over HTTP.")
    parser.add_argument("--host", default="127.0.0.1", help="Host interface to bind. Default: 127.0.0.1")
    parser.add_argument("--port", type=int, default=8000, help="Port to listen on. Default: 8000")
    args = parser.parse_args()

    httpd = ThreadingHTTPServer((args.host, args.port), PlaylistRequestHandler)
    host, port = httpd.server_address

    print(f"Serving {PROJECT_ROOT} at http://{host}:{port}")
    print("Press CTRL+C to stop the server.")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
    finally:
        httpd.server_close()
        print("Server stopped.")


if __name__ == "__main__":
    main()
