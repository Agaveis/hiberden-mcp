# hiberden-mcp: Hiberden MCP server

Exposes the Hiberden archive engine (`hiberden-core`) as [Model Context
Protocol](https://modelcontextprotocol.io) tools over the stdio transport
(newline-delimited JSON-RPC 2.0).

MCP is an open, vendor-neutral standard, so this one server is drivable from any
MCP client: Claude Desktop / Claude Code, OpenAI's Agents SDK and ChatGPT
desktop, Gemini, Cursor, Windsurf, and others. There is no model and no API key
in this process. The client brings the LLM; this binary only answers tool calls
against the local catalog. In its default mode it performs no network I/O.

## Read + verify by default

The server advertises and answers the read/verify tools below by default, and
nothing mutates configuration. The only state any default tool ever writes
is what `verify_copy` records: the copy's status, its verify-pass provenance
(which algorithm ran, when the last full pass succeeded), and an audit-log
row for each completed verify — and it only does that after a genuine
read-back from the medium.

Write and delete tools (catalog management, destinations, policies) ARE
implemented, but behind a catalog-persisted permission tier that defaults to
read-only and is only changeable in the Hiberden desktop app's settings; a
tool above the active tier is neither advertised nor accepted. See
`docs/Hiberden_MCP_Command_Surface_and_Permission_Model.md` (which supersedes
`docs/mcp/write-gate-design.md`).

## Read + verify tools (always on)

| Tool | Args | What it does |
|------|------|--------------|
| `list_projects` | none | Top-level projects (containers). For each: name, policy, archive count, and a roll-up of how many of its archives sit in each coverage state. |
| `list_archives` | `project_id?`, `collection_id?`, `name?` | The archives (leaves actually written to media). For each: project, size, SHA-256, 3-2-1 coverage, and per-copy status (destination + kind + status). Narrow by project, Collection, and/or a case-insensitive name substring. |
| `list_collections` | `project_id` | The Collections inside one project (catalog-only organizational nodes): id, name, parent, archive count. |
| `coverage_status` | none | Library-wide 3-2-1 roll-up: total archives plus counts in unconfigured, unprotected, in_progress, at_risk, and fully_covered. |
| `archive_detail` | `archive_id` | Full detail for one archive: project, size, SHA-256, legacy MD5 (if imported), coverage, and every copy with its destination, kind, status, address, and written/verified timestamps. |
| `list_destinations` | none | Configured destinations (Tape, LocalFs, NAS, Cloud) with id, slot, kind, name, and enabled/retired state. |
| `list_tapes` | none | Tapes: serial, volume label, uuid, capacity, used bytes, last verified time, and copy count. |
| `tape_detail` | `serial` | One cartridge by barcode: label, capacity, used bytes, last verified, and the archives stored on it. |
| `recent_activity` | `limit?` | Recent copy activity, newest first (default 20): each copy's archive, destination, status, and write/verify timestamps. |
| `find_file` | `query`, `limit?` | Find a file by name/path fragment across every archive, with the archive and every destination it is stored in. |
| `list_archive_files` | `archive_id`, `offset?`, `limit?` | The file manifest of one archive from the catalog index (path, size, per-file SHA-256), paginated. The report enabler: client-ready deliverable lists and checksum manifests from the index (a one-time backfill may read a local copy of a pre-index archive). Archives with no buildable index (legacy tape-only imports) report `indexed: false` — manifest unavailable, not empty. |
| `list_jobs` | `limit?` | Recent background jobs (saves, verifies, restores), newest first: verb, state, archive, destination, bytes, timestamps, and the recorded failure reason on failed/interrupted rows. |
| `catalog_stats` | none | One-call inventory + capacity roll-up: counts, total archived bytes, copies by status, destinations by kind, tape capacity vs. use. |
| `verify_copy` | `archive_id`, `destination_id`, `mode?` | Re-reads the copy off its medium and compares it to what was recorded. Default `mode: "full"` re-hashes SHA-256 plus the recorded BLAKE3 and stored signature when present, then stamps the copy Verified on a match, Failed on a mismatch, or Missing if the file is gone — the only pass that can promote. `mode: "fast"` is a BLAKE3-only re-read that sustains an already-Verified copy or exposes a mismatch but never promotes (no recorded fast hash falls back to a full pass, with the reason surfaced). Results and audit rows name the algorithm that ran. |

`verify_copy` is the differentiator: it is proof from the actual medium, not a
stored flag. Identify the copy by `archive_id` + `destination_id`. It works for
disk and NAS copies and for tape copies (the cartridge is mounted and read
back). Cloud (S3) read-back verify runs in the Hiberden desktop app, not here:
for a cloud copy the tool returns a clear message that the copy was checked in
the desktop, not here, so it has not passed or failed. That message is a
not-attempted result, not a verification failure.

Adding archives (writing bytes), save, and restore are not exposed here.
Catalog, destination, and policy configuration tools exist behind the
permission tier described above; at the default read-only tier they are
neither advertised nor accepted.

## Catalog selection

The server reads the single catalog shared by the desktop app, the CLI, and this
server. Path resolution:

1. The `HIBERDEN_DB` environment variable, if set.
2. Otherwise `%LOCALAPPDATA%\Hiberden\catalog.db` on Windows, or
   `~/.hiberden/catalog.db` on Linux.

The catalog is opened fresh per tool call (sub-millisecond) rather than held for
the process lifetime. With WAL mode and a busy timeout, the desktop app and this
server can run against the same `catalog.db` at the same time without a
multi-process locking hazard.

All diagnostics go to stderr. stdout carries the JSON-RPC channel; anything
written to stdout that is not a JSON-RPC message corrupts the stream.

## Linux headless kit (BETA)

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

`hiberden-mcp-linux-x86_64` is the same connector as the Windows build. The
CLI (`hiberden`) catalogs, archives, verifies and restores with no display
server and no network — the whole point of the kit is that an air-gapped or
headless machine can run it.

**What BETA means here, precisely:**

- **Licensing is not wired on Linux yet.** The kit is unlicensed and
  unrestricted; entitlement arrives with Linux GA. Nothing you archive now
  becomes unreadable later: the format and catalog are identical across
  platforms.
- **The desktop app is Windows-only today.** Linux is the CLI + connector.
- **Tape on Linux is unproven on hardware.** The backend targets the
  open-source LTFS implementation and has never run against a drive on any
  platform. Use `HIBERDEN_TAPE_FAKE=1` to exercise the flows without one.
- Archives are signed by a per-install Ed25519 identity stored under
  `~/.hiberden/keys/` (owner-only). It is the same custody model as the OS
  keyrings on other platforms, and no stronger: it is not hardware-backed.

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
default `%LOCALAPPDATA%\Hiberden\catalog.db` path.

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

## Security

- Local-only and closed-domain. The server is read + verify only and performs
  zero network I/O; the only state it writes is the copy status `verify_copy`
  stamps after a read-back. It never sends data to Hiberden or any third party.
- No API key and no LLM are stored in the binary, so there is nothing to steal
  there.
- `verify_copy` gives ground-truth physical state: it re-reads and re-hashes the
  actual medium, so even a manipulated assistant cannot fabricate a "Verified".
- Tool annotations (`readOnlyHint`, `destructiveHint`, and so on) are hints, not
  guarantees. Prompt injection is an unsolved industry-wide problem. The
  architecture here is conservative by design; that is not a claim of immunity.

## Privacy

The server runs entirely on your own machine, holds no account or API key, and
in its default read-and-verify mode performs zero network I/O — it never sends
your catalog or your files to Hiberden or any third party. The only state any
default tool writes is the copy status `verify_copy` stamps after a genuine
read-back. Full details (what the server reads, what it never does, the role of
the separate AI client, and credential handling) are in
[PRIVACY.md](./PRIVACY.md), hosted at <https://hiberden.app/mcp/privacy>.

## Tape caveat

Tape support has been validated on exactly one MagStor LTO-9 drive. The design
never speaks SCSI directly and treats tape as a filesystem via LTFS tooling, so
reading other LTFS generations is architecturally true but not yet broadly
proven on real hardware. Do not read these notes as a guarantee for any specific
drive or generation.

For testing without a drive, the tape backend can run against a fake backend:
set `HIBERDEN_TAPE_FAKE=1` (and optionally `HIBERDEN_TAPE_FAKE_ROOT=<dir>` to
point at a directory standing in for the mounted volume).
