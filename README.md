# Hiberden MCP connector

Point your AI assistant at your **Hiberden** media archive. This is the Model
Context Protocol (MCP) server that ships with the [Hiberden](https://hiberden.app)
desktop app: it exposes your local archive catalog so an assistant (Claude
Desktop, Claude Code, Cursor, Windsurf, ChatGPT, Gemini, or any MCP client) can
answer plain-language questions about your archives and **verify a copy by
reading it back off the medium**.

- **Read and verify by default.** Fourteen tools: thirteen read the catalog
  (projects, archives, collections, 3‑2‑1 coverage, per-archive file manifests,
  destinations, tapes, recent activity, jobs, library stats, file search) and one,
  `verify_copy`, physically re-reads a copy off disk, NAS, or tape, re-hashes it,
  and compares to the recorded SHA‑256 before stamping it Verified.
- **No model, no keys, no network in default mode.** The assistant brings the
  language model; this server only answers tool calls against your own local
  catalog. It never sends your catalog or files to Hiberden or any third party.
- **App-controlled permissions.** Catalog-management and delete tools stay off
  unless a human raises the permission level in the Hiberden desktop app; every
  write is audited.

> Hiberden is verified 3‑2‑1 archiving (not backup) across LTO tape, local disk,
> NAS, and S3‑compatible cloud, with open formats and no vendor lock-in. Learn
> more at **[hiberden.app](https://hiberden.app)** and
> **[hiberden.app/mcp](https://hiberden.app/mcp)**.

## Install

**Easiest — it ships in the app.** Install [Hiberden](https://hiberden.app), open
**Settings → MCP**, and click **Connect** for your assistant. No separate download.

**As a desktop extension (MCPB).** Download `hiberden-<version>.mcpb` from
[Releases](../../releases) and open it in Claude Desktop, then set the connector's
**Catalog database path** to your catalog (default
`%LOCALAPPDATA%\Hiberden\catalog.db`).

**Manually.** Add an `mcpServers.hiberden` entry pointing at the server binary; the
`env.HIBERDEN_DB` is optional (only if your catalog is not at the default path):

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

Full setup guide: **[hiberden.app/kb/connect-an-ai-assistant](https://hiberden.app/kb/connect-an-ai-assistant)**.

## Try it

- "What is my overall 3‑2‑1 coverage right now?"
- "Which projects are unprotected, and where do their copies live?"
- "What's on tape MC0421L9?"
- "Find the file wedding_final_v3.mov — is it saved, and where?"
- "Verify the tape copy of the Johnson family album by reading it back."

More in [`docs/example-prompts.md`](docs/example-prompts.md).

## Tool surface (read + verify, always on)

| Tool | What it does |
|------|--------------|
| `list_projects` | Top-level projects with a coverage roll-up |
| `list_archives` | Archives with size, SHA‑256, 3‑2‑1 coverage, and per-copy status |
| `list_collections` | The middle tier (catalog-only organizational nodes) |
| `coverage_status` | Library-wide 3‑2‑1 roll-up |
| `archive_detail` | Full detail for one archive and every copy |
| `list_destinations` | Configured destinations (tape / disk / NAS / cloud) |
| `list_tapes` / `tape_detail` | Tapes and what's on a given cartridge |
| `recent_activity` | Recent copy activity, newest first |
| `find_file` | Find a file across every archive and where it's stored |
| `list_archive_files` | Per-archive file manifest (path, size, SHA‑256) |
| `list_jobs` | Recent jobs with recorded failure reasons |
| `catalog_stats` | Inventory + capacity roll-up |
| `verify_copy` | Re-read a copy off its medium and prove it against the recorded hash |

Catalog-management and delete tools exist behind an opt-in permission tier set in
the desktop app; at the default read-only tier they are neither advertised nor
accepted. Details: [`manifest.json`](manifest.json).

## Privacy

The server runs entirely on your machine, holds no account or API key, and in its
default mode performs zero network I/O. See [`PRIVACY.md`](PRIVACY.md), hosted at
**[hiberden.app/mcp/privacy](https://hiberden.app/mcp/privacy)**.

## About

Hiberden is a product of **Agave Information Solutions, LLC** (Scottsdale, AZ). The
Hiberden desktop application and archive engine are proprietary; the compiled MCP
server is distributed under the Hiberden license
([EULA](https://hiberden.app/eula)). This repository hosts the connector's
manifest, documentation, and released bundle — not the engine source. Questions:
**support@hiberden.app**.
