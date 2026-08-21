# Local patch set

Fork: `zampierilucas/GyroidVault`. Upstream: `TeeCodeDev/GyroidVault`.

Runs on homelab CT144 (`docker`) at `https://gyroidvault.lzampier.com` — internal
only, no public DNS record, `secured` middleware in Traefik.

## Branches

Each branch is self-contained, based on `main`, and intended as one upstream PR.
`deploy` is the merge of all four and is what production runs. Never commit to
`deploy` directly — commit to a feature branch and re-merge.

| Branch | Change | Upstream |
|---|---|---|
| `fix/guard-library-sync` | `syncLibraryWithDisk` deletes every model when the library is unreadable or empty. Skip the sync instead. | not submitted |
| `feat/filter-by-file-type` | `file_type` query param on `GET /api/models` plus a toolbar select. Also collapses the duplicated filter-param block in `handleFilter`/`goToPage`. | not submitted |
| `feat/f3d-thumbnails` | Extract the embedded Fusion 360 preview from `.f3d` (a zip) as the model thumbnail. | not submitted |
| `perf/parallel-thumbnail-parsing` | `generateThumbnails` parsed each model serially. Move fetch and parse to a worker pool; rendering stays on the main thread. | not submitted |

## Measurements

Worker pool — 30 STL files, 402 MB, 7,049,683 triangles, headless Chromium:

| | serial | pool | |
|---|---|---|---|
| parse only | 5,869 ms | 1,469 ms | 4.00x |
| end to end incl. render | 13,833 ms | 8,921 ms | 1.55x |

End-to-end is limited by the serial WebGL render and by SwiftShader software
rendering in the harness. Output verified byte-identical, 8 of 8 PNGs matched.

Sync guard — pointed at an empty library, stock code deleted all 742 models in
seconds. With the guard, 742 survived and the refusal is logged.

F3D extractor — 7 of 8 real files yielded a thumbnail. The eighth has no
`Previews/` entry and returns null.

## Deploying

    ./deploy/sync.sh

Copies the seven patched files to CT144 and recreates the container. Run from
the repo root with `deploy` checked out. Takes a database backup first.

## Production notes

The container runs the stock upstream image with these files bind-mounted over
it, so `docker compose pull` still updates everything else. Those mounts mask
upstream's copies — when a change lands upstream, drop its branch from `deploy`,
remove the matching mount from `deploy/docker-compose.yml`, and re-run
`sync.sh`.

The library mount sets `create_host_path: false` so Docker refuses to start
rather than silently substituting an empty directory. Keep it until
`fix/guard-library-sync` is upstream — without both, a missing mount wipes the
database.

Backups live on CT144 at `/root/docker-compose/gyroidvault/backup/`.

## Not feasible

- Interactive 3D for `.f3d`. Geometry sits in proprietary `.paramesh` and
  `Breps.BlobParts` blobs with no open reader. Thumbnails only.
- Interactive 3D for STEP needs `occt-import-js`, roughly 9 MB of WebAssembly
  per page load. STEP thumbnails are generated server-side with `f3d` on CT144
  instead.
