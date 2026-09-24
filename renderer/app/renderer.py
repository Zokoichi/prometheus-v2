import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import time
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


APP_VERSION = "PROM-V2-RENDERER-0.1.0"

WORKSPACE = Path("/workspace")
INPUT_DIR = WORKSPACE / "input"
OUTPUT_DIR = WORKSPACE / "output"
TMP_DIR = WORKSPACE / "tmp"


def now_ms():
    return int(time.time() * 1000)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def run_command(command, timeout=None):
    started = now_ms()

    process = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
        check=False,
    )

    elapsed = now_ms() - started

    return {
        "exit_code": process.returncode,
        "stdout": process.stdout,
        "stderr": process.stderr,
        "duration_ms": elapsed,
    }


def ffmpeg_version():
    result = run_command(["ffmpeg", "-version"])

    if result["exit_code"] != 0:
        raise RuntimeError("FFmpeg unavailable")

    first_line = result["stdout"].splitlines()[0] if result["stdout"] else ""

    return first_line


def ffprobe_json(path):
    result = run_command(
        [
            "ffprobe",
            "-v",
            "error",
            "-print_format",
            "json",
            "-show_format",
            "-show_streams",
            str(path),
        ]
    )

    if result["exit_code"] != 0:
        raise RuntimeError(
            "ffprobe failed: " + result["stderr"][-4000:]
        )

    return json.loads(result["stdout"])


def validate_blueprint(blueprint):
    required = [
        "version",
        "profile_id",
        "duration_seconds",
        "timeline",
        "audio",
    ]

    for key in required:
        if key not in blueprint:
            raise ValueError(
                f"Editing Blueprint missing required field: {key}"
            )

    if not isinstance(blueprint["timeline"], list):
        raise ValueError("timeline must be an array")

    if len(blueprint["timeline"]) == 0:
        raise ValueError("timeline must contain at least one segment")

    for index, segment in enumerate(blueprint["timeline"]):
        for key in [
            "segment_id",
            "start_seconds",
            "end_seconds",
            "scene_number",
            "visuals",
        ]:
            if key not in segment:
                raise ValueError(
                    f"timeline[{index}] missing required field: {key}"
                )

        if segment["end_seconds"] <= segment["start_seconds"]:
            raise ValueError(
                f"timeline[{index}] has invalid temporal range"
            )

        if not isinstance(segment["visuals"], list):
            raise ValueError(
                f"timeline[{index}].visuals must be an array"
            )

    audio = blueprint["audio"]

    if "voice_artifacts" not in audio:
        raise ValueError("audio.voice_artifacts missing")

    if "master" not in audio:
        raise ValueError("audio.master missing")


def resolve_local_asset(asset):
    """
    P2.1 deliberately accepts local mounted assets.

    Production S3/SeaweedFS retrieval is implemented as a separate
    storage adapter boundary in the next renderer increment.

    This prevents the renderer from embedding storage-specific logic.
    """

    if isinstance(asset, str):
        path = Path(asset)
    elif isinstance(asset, dict):
        if "local_path" not in asset:
            raise ValueError(
                "Asset object must contain local_path in P2.1"
            )
        path = Path(asset["local_path"])
    else:
        raise ValueError("Invalid asset reference")

    if not path.is_absolute():
        path = INPUT_DIR / path

    path = path.resolve()

    allowed_roots = [
        INPUT_DIR.resolve(),
        TMP_DIR.resolve(),
    ]

    if not any(
        str(path).startswith(str(root) + os.sep)
        or path == root
        for root in allowed_roots
    ):
        raise ValueError(
            f"Asset path outside renderer workspace: {path}"
        )

    if not path.exists():
        raise FileNotFoundError(str(path))

    return path


def build_test_render(output_path, duration=5):
    """
    Deterministic synthetic render used exclusively for renderer
    infrastructure validation.

    This is NOT the production editorial renderer yet.
    """

    command = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "lavfi",
        "-i",
        f"color=c=black:s=1080x1920:r=30:d={duration}",
        "-f",
        "lavfi",
        "-i",
        f"sine=frequency=440:sample_rate=48000:duration={duration}",
        "-vf",
        (
            "drawtext="
            "fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:"
            "text='PROMETHEUS V2 RENDER TEST':"
            "fontcolor=white:"
            "fontsize=58:"
            "x=(w-text_w)/2:"
            "y=(h-text_h)/2"
        ),
        "-c:v",
        "libx264",
        "-preset",
        "veryfast",
        "-crf",
        "20",
        "-pix_fmt",
        "yuv420p",
        "-r",
        "30",
        "-c:a",
        "aac",
        "-b:a",
        "192k",
        "-ar",
        "48000",
        "-ac",
        "2",
        "-movflags",
        "+faststart",
        "-t",
        str(duration),
        str(output_path),
    ]

    return run_command(command, timeout=120)


def perform_qa(path):
    evidence = {
        "status": "FAIL",
        "checks": [],
    }

    try:
        probe = ffprobe_json(path)

        streams = probe.get("streams", [])
        video = next(
            (s for s in streams if s.get("codec_type") == "video"),
            None,
        )
        audio = next(
            (s for s in streams if s.get("codec_type") == "audio"),
            None,
        )

        def check(name, passed, detail):
            evidence["checks"].append(
                {
                    "name": name,
                    "status": "PASS" if passed else "FAIL",
                    "detail": detail,
                }
            )

        check(
            "file_exists",
            path.exists(),
            str(path),
        )

        check(
            "video_stream",
            video is not None,
            "video stream present",
        )

        check(
            "audio_stream",
            audio is not None,
            "audio stream present",
        )

        if video:
            check(
                "resolution",
                video.get("width") == 1080
                and video.get("height") == 1920,
                f"{video.get('width')}x{video.get('height')}",
            )

            check(
                "video_codec",
                video.get("codec_name") == "h264",
                str(video.get("codec_name")),
            )

        if audio:
            check(
                "audio_codec",
                audio.get("codec_name") == "aac",
                str(audio.get("codec_name")),
            )

            check(
                "audio_sample_rate",
                str(audio.get("sample_rate")) == "48000",
                str(audio.get("sample_rate")),
            )

        duration = float(
            probe.get("format", {}).get("duration", 0)
        )

        check(
            "duration_positive",
            duration > 0,
            str(duration),
        )

        check(
            "mp4_format",
            probe.get("format", {}).get("format_name", "")
            .split(",")[0]
            == "mov",
            probe.get("format", {}).get("format_name"),
        )

        failed = [
            c for c in evidence["checks"]
            if c["status"] == "FAIL"
        ]

        evidence["status"] = (
            "PASS" if not failed else "FAIL"
        )

        evidence["duration_seconds"] = duration
        evidence["sha256"] = sha256_file(path)
        evidence["size_bytes"] = path.stat().st_size

        return evidence

    except Exception as exc:
        evidence["status"] = "FAIL"
        evidence["error"] = str(exc)
        return evidence


class Handler(BaseHTTPRequestHandler):

    def send_json(self, status, payload):
        data = json.dumps(
            payload,
            ensure_ascii=False,
            indent=2,
        ).encode("utf-8")

        self.send_response(status)
        self.send_header(
            "Content-Type",
            "application/json; charset=utf-8",
        )
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        route = urlparse(self.path).path

        if route == "/health":
            self.send_json(
                200,
                {
                    "status": "PASS",
                    "service": "prometheus-v2-renderer",
                    "version": APP_VERSION,
                    "ffmpeg": ffmpeg_version(),
                },
            )
            return

        if route == "/version":
            self.send_json(
                200,
                {
                    "service": "prometheus-v2-renderer",
                    "version": APP_VERSION,
                    "ffmpeg": ffmpeg_version(),
                },
            )
            return

        self.send_json(
            404,
            {
                "status": "FAIL",
                "error": "route_not_found",
            },
        )

    def do_POST(self):
        route = urlparse(self.path).path

        try:
            length = int(
                self.headers.get("Content-Length", "0")
            )

            body = self.rfile.read(length)

            payload = json.loads(body.decode("utf-8"))

            if route == "/render/test":
                requested_duration = float(
                    payload.get("duration_seconds", 5)
                )

                if requested_duration <= 0:
                    raise ValueError(
                        "duration_seconds must be positive"
                    )

                if requested_duration > 30:
                    raise ValueError(
                        "P2.1 test render maximum is 30 seconds"
                    )

                output_path = (
                    OUTPUT_DIR
                    / "renderer-test.mp4"
                )

                result = build_test_render(
                    output_path,
                    requested_duration,
                )

                if result["exit_code"] != 0:
                    self.send_json(
                        500,
                        {
                            "status": "FAIL",
                            "stage": "FFMPEG_RENDER",
                            "result": result,
                        },
                    )
                    return

                qa = perform_qa(output_path)

                status = (
                    200 if qa["status"] == "PASS"
                    else 500
                )

                self.send_json(
                    status,
                    {
                        "status": qa["status"],
                        "service_version": APP_VERSION,
                        "render": {
                            "engine": "FFMPEG",
                            "duration_requested_seconds":
                                requested_duration,
                            "output":
                                str(output_path),
                            "render_duration_ms":
                                result["duration_ms"],
                        },
                        "qa": qa,
                    },
                )

                return

            if route == "/validate/blueprint":
                validate_blueprint(payload)

                self.send_json(
                    200,
                    {
                        "status": "PASS",
                        "validation":
                            "EDITING_BLUEPRINT_STRUCTURE",
                    },
                )

                return

            self.send_json(
                404,
                {
                    "status": "FAIL",
                    "error": "route_not_found",
                },
            )

        except Exception as exc:
            self.send_json(
                400,
                {
                    "status": "FAIL",
                    "error": str(exc),
                },
            )

    def log_message(self, format, *args):
        print(
            "[HTTP] "
            + format % args,
            flush=True,
        )


def main():
    INPUT_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)

    print(
        f"{APP_VERSION} starting",
        flush=True,
    )

    print(
        ffmpeg_version(),
        flush=True,
    )

    server = ThreadingHTTPServer(
        ("0.0.0.0", 8080),
        Handler,
    )

    print(
        "Renderer listening on 0.0.0.0:8080",
        flush=True,
    )

    server.serve_forever()


if __name__ == "__main__":
    main()
