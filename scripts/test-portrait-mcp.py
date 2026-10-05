#!/usr/bin/env python3
"""Exercise the real stdio transport against a supplied local portrait in a disposable session."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import uuid


def run(executable, photo, output):
    before = hashlib.sha256(photo.read_bytes()).hexdigest()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="portrait-mcp-test-") as directory:
        sidecar = Path(directory) / "edit.json"
        process = subprocess.Popen(
            [str(executable), "--photo", str(photo), "--document", str(sidecar)],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        request_id = 0

        def send(method, params, notification=False):
            nonlocal request_id
            request_id += 1
            message = {"jsonrpc": "2.0", "method": method, "params": params}
            if not notification:
                message["id"] = request_id
            process.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
            process.stdin.flush()
            if notification:
                return None
            response = json.loads(process.stdout.readline())
            assert response["id"] == request_id, response
            assert "error" not in response, response
            return response["result"]

        def call(name, arguments):
            return send("tools/call", {"name": name, "arguments": arguments})

        def metadata(result):
            return json.loads(next(item["text"] for item in result["content"] if item["type"] == "text"))

        try:
            initialized = send("initialize", {
                "protocolVersion": "2025-06-18", "capabilities": {},
                "clientInfo": {"name": "portrait-integration-test", "version": "1"},
            })
            send("notifications/initialized", {}, notification=True)
            tools = send("tools/list", {})["tools"]
            assert {tool["name"] for tool in tools} == {"analyze_faces", "render_preview_with", "set_stack"}
            photo_id = before[:16]
            analysis = metadata(call("analyze_faces", {"photo_id": photo_id}))
            assert len(analysis["faces"]) > 0, analysis
            proposed = [
                {"kind": {"tone": {"exposure": 0.1}}},
                {"kind": {"skin": {"strength": 0.3, "texturePreservation": 0.85, "radius": 12}}},
            ]
            preview = call("render_preview_with", {"photo_id": photo_id, "stack": proposed, "max_size": 1024})
            assert not preview.get("isError"), preview
            ticket = metadata(preview)
            assert not sidecar.exists(), "Preview must not save edits"
            image = next(item for item in preview["content"] if item["type"] == "image")
            decoded = base64.b64decode(image["data"], validate=True)
            assert decoded[:2] == b"\xff\xd8", "Expected a JPEG image content block"
            (output / "mcp-preview.jpg").write_bytes(decoded)
            arguments = {
                "photo_id": photo_id, "stack": ticket["stack"], "preview_id": ticket["preview_id"],
                "expected_revision": ticket["revision"], "session_id": str(uuid.uuid4()), "confirmed": False,
            }
            assert call("set_stack", arguments).get("isError"), "An unconfirmed request must fail"
            assert not sidecar.exists()
            # This is a transaction test, not a claim that a person accepted the proposed edit.
            arguments["confirmed"] = True
            applied = call("set_stack", arguments)
            assert not applied.get("isError"), applied
            assert metadata(applied)["revision"] == 1
            persisted = json.loads(sidecar.read_text())
            assert len(persisted["ops"]) == 2
            assert persisted["ops"][0]["origin"]["ai"]["sessionID"].lower() == arguments["session_id"]
            assert call("set_stack", arguments).get("isError"), "Replayed approval must fail"
            assert sidecar.with_suffix(".json.analysis.json").exists()
            report = {
                "photo_id": photo_id, "faces": len(analysis["faces"]), "tools": len(tools),
                "previewReturnedImage": True, "previewDidNotSave": True,
                "unconfirmedRejected": True, "confirmedTransactionSaved": True,
                "replayedRequestRejected": True, "approvalSimulatedForTest": True,
                "persistentUserEditApplied": False,
                "sourceUnchanged": before == hashlib.sha256(photo.read_bytes()).hexdigest(),
                "server": initialized["serverInfo"],
            }
            assert report["sourceUnchanged"]
            (output / "mcp-integration.json").write_text(json.dumps(report, indent=2))
            print(json.dumps(report))
        finally:
            process.stdin.close()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            errors = process.stderr.read()
            if process.returncode:
                raise RuntimeError(errors or f"Server exited {process.returncode}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("photo", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    run(args.executable.resolve(), args.photo.resolve(), args.output.resolve())
