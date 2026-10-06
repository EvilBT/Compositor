# Portrait analysis and MCP prototype

The host keeps `PortraitSession`, `FaceAnalyzer`, `PortraitRenderer` and `MCPServer`
in one process. It is a headless Mac prototype, not yet a native editor or an integration
with the existing Compositor application. The libraries also compile for iOS.

## Review a real photo

From `PortraitFoundation`:

```sh
swift run -c release portrait-mcp --photo /path/portrait.jpg --review /path/review
```

The source is read-only. Review mode does not apply or save a stack. It exports an upright
2048-pixel preview, skin coverage, a green coverage overlay, three candidate previews,
native-resolution face crops, a four-panel comparison and measured texture statistics.
The columns are original, conservative, standard, strong. These labels describe candidates,
not presets validated across different people. Do not combine `--review` with an existing
`--document`: review expects a new, empty editing session.

The initial real-photo test uses `0229_95_1.jpg`, 7008×4672, stored outside the repository.
One face was detected. Its native 892×892 crop retained 96.3%, 85.4%, 70.6% Laplacian
energy for strength/texture pairs 0.30/0.85, 0.50/0.70, 0.65/0.55. (Those were the candidates at the time. The set has since been re-centred on the level chosen from a later photograph; see `PortraitHost.reviewCandidates`.) (Those were the candidates at the time. The set has since been re-centred on the level chosen from a later photograph; see `PortraitHost.reviewCandidates`.) The measure uses red
channel Laplacians entirely inside high coverage; it does not label all image variation
as skin texture. Zero-coverage pixels changed in none of the candidates.

The whole-frame previews and the native crops are rendered separately; review the native
crop to judge pores. This prototype does not export the full 32.7MP retouched photograph.

## Analysis limits

Vision rectangle revision 3 and landmark revision 3 supply coordinates. Conversion to
top-left image coordinates happens exactly once. EXIF orientation is applied by ImageIO
before analysis. Eyes, brows and lips are excluded geometrically; cheeks seed an adaptive
chroma prior inside a conservative jaw/forehead hull. Pale highlights are protected relative
to the sampled face illumination. This is a heuristic mask, not neural skin segmentation.
Profiles, occlusion, facial hair and unusual makeup require manual review.

Cheek/jaw-related semantic points may be inferred rather than directly detected. Subject-left
mapping assumes an upright, unmirrored frontal face. Indices are sorted by image position,
not persistent person tracking. Face identity across redetection or multiple photographs
is unimplemented.

`luminanceStdDev` includes lighting and makeup, not just pores. `analyze_faces` now exposes
conservative `blemishes` with face-relative anchors, face-width radii, heuristic confidence
and `blemishDetectorVersion`; `blemishDetectionAvailable` is true after detection.
`blemishFraction` measures the union of candidate disks intersecting skin coverage >=128,
divided by that face's coverage >=128 pixel count. It is not a calibrated acne density;
zero can mean omission, not clear skin. The default detection threshold is 0.8.
Candidates require review, especially around moles, freckles, facial hair and decorations.
Nose shading, highlights and non-red defects are deliberately omitted.
A nonzero `skin.blemishStrength` remains an error and `.blemish` rendering is still
unsupported (T4/T5). Do not derive stronger smoothing from these statistics alone.

Detection uses local RGB contrast at several face-relative scales with an integral-image
background and surrounding-ring checks. It adds no model or image repair dependency.
Legacy analysis caches gain optional candidate metadata using their frozen skin mask;
coverage is not regenerated. New metadata is saved with the next explicit session save
or accepted edit. Source pixels, existing skin masks and skin render versions are unchanged.
Reproduction and real-photo limitations: `../scripts/blemish-trial/README.md`.

## Renderer coverage

`PortraitRenderer` supports `skin`, `tone`, `whiteBalance`, `presence`, and point `toneCurve`.
Relative white balance is explicitly a channel-gain adjustment, not Kelvin or camera-profile
chromatic adaptation. Exposure uses linear sRGB; the remaining controls are deterministic
reference approximations. Parametric curves and refine saturation are rejected explicitly.
Every enabled known operation outside this subset fails. Disabled operations and unknown
saved kinds retain the core model's behavior. Existing skin v1/v2 byte fingerprints remain
unchanged, and develop+skin stacks match independent step folds at tolerance zero.

## Connect an MCP client

Build the executable and find its path:

```sh
swift build -c release
swift build -c release --show-bin-path
```

Configure the client's stdio server command with the repository launcher and arguments.
The launcher builds the host when needed and keeps build output on stderr:

```json
{
  "mcpServers": {
    "portrait": {
      "command": "/absolute/repository/path/scripts/portrait-mcp.sh",
      "args": ["--photo", "/path/portrait.jpg", "--document", "/path/edit.json"]
    }
  }
}
```

The host implements newline-delimited JSON-RPC, initialization and exactly three tools.
It negotiates 2024-11-05, 2025-03-26 or 2025-06-18; other versions receive its newest
supported version. No HTTP transport, sampling, cancellation or native approval UI is
implemented. These follow the official [stdio transport](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports)
and [tools](https://modelcontextprotocol.io/specification/2025-06-18/server/tools) specifications.

1. `analyze_faces(photo_id)` returns structured text and a PNG coverage image. The photo ID
   is announced in the initialization instructions; it is derived from the source SHA-256.
2. `render_preview_with(photo_id, stack, max_size?, process_version?)` returns a JPEG image
   and canonical stack/ticket metadata. Omitted parameters receive defaults; IDs are assigned
   if omitted. Named point-curve channels are accepted at this boundary. Previews never save.
3. `set_stack(photo_id, stack, preview_id, expected_revision, session_id, confirmed)` requires
   the exact canonical stack from an unexpired ticket. A replay or stale revision fails.
   `confirmed: true` is an assertion by the client; the client or native host must obtain
   actual human approval. The flag itself is not proof of consent.

At most four preview tickets are retained. Stack writes have a 100-step undo ceiling.
Unchanged operations keep provenance; changed/new operations are tagged with the AI session.
`PortraitSession.undo()` restores the entire previous document, including replaced user work.
It is a native-host API, not a fourth exposed MCP tool. The headless host has no undo UI yet.

With `--document`, successful changes and undo save atomically. A sidecar analysis cache stores
the exact coverage so intact caches survive future detector changes. Corrupt/missing caches
are regenerated; exact historic pixels are then not guaranteed. The source hash must match
when reopening. Coordinated writes reject external modifications instead of overwriting them.
Undo history is in memory and does not survive a restart. Without `--document`, all edits
are disposable in-memory state. No tools can choose new filesystem paths.

## Validation

```sh
swift test
swift test -c release
swift build --triple arm64-apple-ios18.0 \
  --sdk "$(xcrun --sdk iphoneos --show-sdk-path)" --scratch-path /tmp/portrait-ios
python3 ../scripts/test-portrait-mcp.py /absolute/path/portrait-mcp /path/portrait.jpg /path/review
```

The Python check drives a real stdio subprocess, analyzes the actual photo, receives an image,
rejects an unconfirmed write, simulates confirmation in a disposable sidecar, and rejects replay.
It does not claim a person approved the photo. Unit tests cover whole-document undo, reopen,
write failure and external-change protection. Actual human approval, native UI and client-specific
connection behavior remain to be tested. Private photos and generated review artifacts are not
included in the repository.
