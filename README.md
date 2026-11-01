# hiberden-mcp: Hiberden MCP server

Exposes the Hiberden archive engine (`hiberden-core`) as [Model Context
Protocol](https://modelcontextprotocol.io) tools over the stdio transport
(newline-delimited JSON-RPC 2.0).

MCP is an open, vendor-neutral standard, so this one server is drivable from any
MCP client that launches local servers over stdio: Claude Desktop / Claude Code,
OpenAI's Agents SDK and Codex CLI, Gemini CLI, Cursor, Windsurf, and
others. There is no model and no API key in this process. The client brings the
LLM; this binary only answers tool calls against the local catalog. It makes no
network requests of its own.

**Versions.** The Hiberden app (2.0.0, for Windows, macOS and Linux) ships
connector 2.0.0 inside it. The latest release on this repository's releases
page, the standalone connector downloads on cdn.hiberden.app and the
`agaveis/hiberden-mcp` Docker image are connector 1.3.2. Where this README
describes something the two builds do differently, it names the build.

## Read + verify by default

The server advertises and answers the read/verify tools below by default, and
nothing mutates configuration. At the default tier the server writes what
`verify_copy` records after it checks the medium (the copy's status, its
verify-pass provenance, meaning which algorithm ran and when the last full pass
succeeded, and an audit-log row), an audit-log row for each refused call to a
tool above the tier, and the catalog's per-file index for an archive written
before that index existed, built from its local or NAS copy. Connector 1.3.2
builds that index when `find_file` or `list_archive_files` runs; 2.0.0 builds it
once, when the server starts. When the server starts it also creates an empty
catalog if there is none at the path, and opening a catalog from an older
version brings its schema up to date.

Write and delete tools (catalog management, destinations, policies) ARE
implemented, but behind a catalog-persisted permission tier that defaults to
read-only and is only changeable in the Hiberden desktop app (Settings, then
MCP, Access level). A tool above the active tier is not advertised, and a call
to one is refused and recorded in the audit log. Deletes also need a separate
delete override, off by default. The levels are described at
<https://hiberden.app/mcp>.

## Read + verify tools (always on)

| Tool | Args | What it does |
|------|------|--------------|
| `list_projects` | none | Top-level projects (containers). For each: name, policy, archive count, and a roll-up of how many of its archives sit in each coverage state. |
| `list_archives` | `project_id?`, `collection_id?`, `name?` | The archives (leaves actually written to media). For each: project, size, SHA-256, 3-2-1 coverage, and per-copy status (destination + kind + status). Narrow by project, Collection, and/or a case-insensitive name substring. |
| `list_collections` | `project_id` | The Collections inside one project (catalog-only organizational nodes): id, name, parent, archive count. |
| `coverage_status` | none | Library-wide 3-2-1 roll-up: total archives plus counts in unconfigured, unprotected, in_progress, at_risk, and fully_covered. |
| `archive_detail` | `archive_id` | Full detail for one archive: project, size, SHA-256, legacy MD5 (if imported), coverage, and every copy with its destination, kind, status, address, and written/verified timestamps. |
| `list_destinations` | none | Configured destinations (Tape, LocalFs, NAS, Cloud) with id, slot, kind, name, and enabled/retired state. |
| `list_policies` | none | Connector 2.0.0 only: every protection policy with its retention, the projects that use it, and each destination it is bound to, with the binding id `remove_binding` takes. |
| `list_tapes` | none | Tapes: serial, volume label, uuid, capacity, used bytes, and copy count. |
| `tape_detail` | `serial` | One cartridge by barcode: label, capacity, used bytes, and the archives whose copy starts on it. |
| `recent_activity` | `limit?` | Recent copy activity, newest first (default 20): each copy's archive, destination, status, and write/verify timestamps. |
| `find_file` | `query`, `limit?` | Find a file by name/path fragment across every archive, with the archive and every destination it is stored in. |
| `list_archive_files` | `archive_id`, `offset?`, `limit?` | The file manifest of one archive from the catalog index (path, size, per-file SHA-256), paginated. The report enabler: client-ready deliverable lists and checksum manifests from the index (a one-time backfill may read a local copy of a pre-index archive). Archives with no buildable index (legacy tape-only imports) report `indexed: false`: the manifest is unavailable, not empty. |
| `list_jobs` | `limit?` | Recent background jobs (saves, verifies, restores), newest first: verb, state, archive, destination, bytes, timestamps, and the recorded failure reason on failed/interrupted rows. |
| `catalog_stats` | none | One-call inventory + capacity roll-up: counts, total archived bytes, copies by status, destinations by kind, tape capacity vs. use. |
| `verify_copy` | `archive_id`, `destination_id`, `mode?` (2.0.0 adds `cold?` for tape) | Re-reads the copy off its medium and compares it to what was recorded. Default `mode: "full"` re-hashes SHA-256 plus the recorded BLAKE3 and stored signature when present, then stamps the copy Verified on a match, Failed on a mismatch, or Missing if the file is not found, with the exceptions below; it is the only pass that can promote. `mode: "fast"` is a BLAKE3-only re-read that sustains an already-Verified copy or exposes a mismatch but never promotes (no recorded fast hash falls back to a full pass, with the reason surfaced). Results and audit rows name the algorithm that ran. |

`verify_copy` is the differentiator: it is proof from the actual medium, not a
stored flag. Identify the copy by `archive_id` + `destination_id`.

- **Disk and NAS.** The copy is re-read and re-hashed. When a copy's file is not
  found, connector 2.0.0 marks it Missing only if its location answers, and
  otherwise changes nothing; 1.3.2 marks it Missing whenever its file is not
  found, including when its disk is unplugged or its share is off.
- **Tape.** It re-reads a tape copy stored as a single .tar file, such as one
  adopted by the `hiberden scan-tape` command. Every tape copy the Hiberden
  desktop writes is stored in parts, which `verify_copy` cannot read: 2.0.0
  refuses those copies and changes nothing, and 1.3.2 can mark them Missing, so
  do not run 1.3.2's `verify_copy` on a tape copy the desktop wrote. On tape,
  2.0.0 marks a copy Verified only from a cold read, one where it mounted the
  cartridge itself (`cold: true` unmounts and remounts first). With a different
  cartridge in the drive, 2.0.0 changes nothing, and it names the cartridge to
  load when the catalog records which one holds the copy.
- **Cloud (S3).** Read-back verify runs in the Hiberden desktop app, not here.
  For a cloud copy the tool returns a message that the copy was not checked
  here, so it has neither passed nor failed. That is a not-attempted result,
  not a verification failure.

Adding archives (writing bytes), save, and restore are not exposed here.
Catalog, destination, and policy configuration tools exist behind the
permission tier described above; at the default read-only tier they are
neither advertised nor accepted.

## Catalog selection

The server reads the single catalog shared by the desktop app, the CLI, and this
server. Path resolution:

1. The `HIBERDEN_DB` environment variable, if set.
2. Otherwise `%LOCALAPPDATA%\Hiberden\catalog.db` on Windows,
   `~/Library/Application Support/Hiberden/catalog.db` on macOS (connector
   2.0.0, inside the Hiberden app), or `~/.hiberden/catalog.db` on Linux.

The catalog is opened fresh per tool call (sub-millisecond) rather than held for
the process lifetime. With WAL mode and a busy timeout, the desktop app and this
server can run against the same `catalog.db` at the same time without a
multi-process locking hazard.

All diagnostics go to stderr. stdout carries the JSON-RPC channel; anything
written to stdout that is not a JSON-RPC message corrupts the stream.

## Linux headless kit

Linux binaries are published on the [releases](../../releases) page and at
`cdn.hiberden.app`. They are built on Ubuntu 22.04, so they run on Ubuntu
22.04+, Debian 12+, and equivalents; verified on `debian:bookworm-slim` and
`ubuntu:22.04`.

```sh
curl -fsSLO https://cdn.hiberden.app/downloads/hiberden-cli-linux-x86_64
curl -fsSLO https://cdn.hiberden.app/downloads/hiberden-cli-linux-x86_64.sha256
sha256sum -c hiberden-cli-linux-x86_64.sha256      # verify before running it
chmod +x hiberden-cli-linux-x86_64
./hiberden-cli-linux-x86_64 --version
```

`hiberden-mcp-linux-x86_64` is connector 1.3.2, the same build as the Windows
bundle on the releases page. The
CLI (`hiberden`) catalogs and archives with no display server and no network;
the whole point of the kit is that an air-gapped or headless machine can run
it.

Linux reached general availability on 2026-08-11 at version 1.3.1, alongside
Windows. **What that does and does not cover, precisely:**

- **Writing a new archive needs a license.** Reading your data back never does,
  license or not. Kits published before GA are ungated and stay that way;
  entitlement applies from the first post-GA kit onward. Nothing you archive
  now becomes unreadable later: the format and catalog are identical across
  platforms.
- **The desktop app runs on Linux too**, as a signed `.deb` and `.AppImage`
  from [hiberden.app/linux](https://hiberden.app/linux). The macOS build for
  Apple Silicon is at [hiberden.app/download](https://hiberden.app/download).
- **Tape on Linux is unproven on hardware.** The backend targets the
  open-source LTFS implementation and has never run against a drive on any
  platform. Use `HIBERDEN_TAPE_FAKE=1` to exercise the flows without one.
- Archives are signed by a per-install Ed25519 identity stored under
  `~/.hiberden/keys/` (owner-only). Like the OS keyrings on other platforms, it
  keeps the key from other users on the machine; it is not hardware-backed.

## Setup

The binary self-installs into known MCP clients:

```
hiberden-mcp install          # auto-detect Claude Desktop / Cursor / Windsurf and write their config
hiberden-mcp install --print  # print a paste-ready snippet instead of touching anything
hiberden-mcp uninstall        # remove the hiberden entry from detected clients
hiberden-mcp help             # show usage
```

`install` writes (or updates) an `mcpServers.hiberden` entry pointing at this
executable. It is zero-config for the catalog: the entry only pins `HIBERDEN_DB`
when you already have it set in your environment, otherwise it relies on the
default path for this computer (see Catalog selection above).

### Manual configuration

To wire it up by hand, add this to your client's config (Claude Desktop:
`claude_desktop_config.json`; Claude Code: `.mcp.json`; Cursor / Windsurf use the
same `mcpServers` shape). `command` is the path to the executable. `env` is
optional: include `HIBERDEN_DB` only if your catalog lives somewhere other than
the default path.

```json
{
  "mcpServers": {
    "hiberden": {
      "command": "C:/path/to/hiberden-mcp.exe",
      "env": { "HIBERDEN_DB": "C:/path/to/catalog.db" }
    }
  }
}
```

## Smoke test (no client needed)

This pipes three requests (initialize, list tools, read coverage) straight into
the binary:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{}}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"coverage_status","arguments":{}}}' \
  | HIBERDEN_DB=path/to/catalog.db hiberden-mcp
```

## Container image

The image on Docker Hub, `agaveis/hiberden-mcp`, is the same connector binary
in a `debian:bookworm-slim` container. It carries no catalog: it starts, reports
itself, and advertises the read-only tool surface, but there are no archives to
answer questions about. This is not how you run Hiberden. For real use, install
Hiberden from https://hiberden.app.

The image exists so MCP directories can run their introspection handshake
(initialize, then tools/list) against the connector in a Linux sandbox, and so
anyone can inspect the advertised tool surface without installing anything.

To point it at a real catalog, mount one and set `HIBERDEN_DB`:

```sh
docker run --rm -i -v /var/lib/hiberden:/cat -e HIBERDEN_DB=/cat/catalog.db agaveis/hiberden-mcp
```

The connector reads that catalog. At the default tier it writes what a verify
records, its audit-log rows and the per-file index for older archives; the write
tools unlock only if the catalog's own tier allows them.

## Security

- Local-only and closed-domain. At the default tier the server reads and
  verifies; write and delete tools unlock only behind the tier set in the
  desktop. It makes no network requests of its own and never sends data to
  Hiberden or any third party.
- No API key and no LLM are stored in the binary, so there is nothing to steal
  there.
- `verify_copy` gives ground-truth physical state for a disk or NAS copy: it
  re-reads and re-hashes the actual medium, so even a manipulated assistant
  cannot fabricate a "Verified".
- Tool annotations (`readOnlyHint`, `destructiveHint`, and so on) are hints, not
  guarantees. Prompt injection is an unsolved industry-wide problem. The
  architecture here is conservative by design; that is not a claim of immunity.

## Privacy

The server runs entirely on your own machine, holds no account or API key, and
makes no network requests of its own: it never sends your catalog or your files
to Hiberden or any third party. What it writes at the default tier is listed
under "Read + verify by default" above. Full details (what the server reads, what it never does, the role of
the separate AI client, and credential handling) are in
[PRIVACY.md](./PRIVACY.md), hosted at <https://hiberden.app/mcp/privacy>.

## Tape caveat

Tape support has not been validated on physical tape hardware in
this implementation. The design never speaks SCSI directly and treats tape as a
filesystem via LTFS tooling. That is an architectural property, not a tested hardware
matrix. Do not read these notes as a guarantee for any specific drive or
generation.

For testing without a drive, the tape backend can run against a fake backend:
set `HIBERDEN_TAPE_FAKE=1` (and optionally `HIBERDEN_TAPE_FAKE_ROOT=<dir>` to
point at a directory standing in for the mounted volume).

**Website:** https://hiberden.app

**Listing and source:** https://github.com/Agaveis/hiberden-mcp

Built and maintained by [AgaveIS](https://agaveis.com), Scottsdale, Arizona.
