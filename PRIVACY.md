# Hiberden MCP Server: Privacy Policy

**Last updated:** 2026-11-01

## Summary

The Hiberden MCP server runs entirely on your own computer. It reads your local
Hiberden archive catalog so an AI assistant you have connected (for example
Claude Desktop, Claude Code, or Cursor) can answer plain-language questions about
your archives and verify your copies. The server sends nothing to Hiberden and
nothing to any other company. There is no account, no sign-up, no telemetry, and
no cloud upload performed by this server. Your files stay on your machine and on
the storage you already control, and the server returns catalog facts only to
the AI client you connect. Connecting a station to Central Library is a
separate, deliberate act performed in the desktop app; the Hiberden Privacy
Policy (<https://hiberden.app/privacy>) describes what that sends.

## What this document covers

This policy describes the Hiberden MCP server only: the local program
(`hiberden-mcp`) that exposes your archive catalog to an MCP-capable AI client.
It does not cover the Hiberden desktop application or the AI client you connect
(see "The role of the separate AI client" below).

## What data the server accesses

The server reads and acts on data that already lives on your own computer and on
the storage you have configured:

- **The local catalog database.** The server reads your Hiberden catalog,
  resolved from the `HIBERDEN_DB` environment variable if set, otherwise from
  the default location: `%LOCALAPPDATA%\Hiberden\catalog.db` on Windows,
  `~/Library/Application Support/Hiberden/catalog.db` on macOS, and
  `~/.hiberden/catalog.db` on Linux. This is the same SQLite database the
  desktop app and command-line tool use. It contains your projects, Collections,
  archives, destinations, tapes, copy records, the per-file index of each
  archive (relative file paths, sizes, and per-file hashes), background job
  records (including recorded failure text, which can mention file paths and
  storage locations), a local audit log of assistant actions, sizes, SHA-256
  hashes, status fields, and timestamps. The server opens the database when it
  starts and each time the assistant lists or calls its tools.
- **Local disk and NAS file contents during a verify.** When you (through the
  assistant) run `verify_copy` on a disk or NAS copy, the server re-reads that
  copy from the local file system or the network share and re-hashes it. In the
  default `full` mode it compares against the recorded SHA-256, the recorded
  BLAKE3, and the stored signature when one is present; in `fast` mode it
  re-reads the same bytes and compares against the recorded BLAKE3 only. Either
  way the file is read on your computer, and the server does not send its
  contents anywhere.
- **Tape contents during a verify.** In Hiberden 2.0, `verify_copy` does not
  re-read a tape copy the desktop wrote: it says so and leaves the copy's status
  as it was. For a tape copy adopted from an existing cartridge, the server reads
  the copy back from the cartridge, mounting it first if it is not mounted, to
  re-hash it. As with disk and NAS, the data is read locally and is not
  transmitted.

The server returns only catalog facts and verify results (for example a status
of Verified, Failed, or Missing, together with which hash algorithm the pass
ran) to the connected AI client over the local stdio channel. It does not
return raw file contents.

## What the server does NOT do

- **No telemetry.** The server collects no usage data and reports nothing about
  how, when, or whether you use it.
- **No analytics.** There is no measurement, profiling, or behavioral tracking.
- **No phone-home.** The server makes no network requests of its own and never
  contacts Hiberden or any third party. When it reads a copy on a NAS, it reads
  it through your computer's own connection to that share.
- **No account.** There is no log-in, no user identity, and no registration.
- **No cloud upload by the server.** The server itself never uploads your files
  to any cloud service. Confirming a cloud copy is a separate function that runs
  in the Hiberden desktop application, not in this server. When asked to verify a
  cloud copy, the server returns a clear message that the check is performed in
  the desktop app and that the copy has neither passed nor failed here.
- **No credentials through the AI.** No API key, password, or cloud secret is
  ever passed through the AI client or stored in the server binary. There is no
  model and no API key inside this program; there is nothing of that kind to
  collect or leak from it.

## The role of the separate AI client

The Hiberden MCP server contains no AI model and no language model. The
intelligence comes from the separate AI client you connect, such as Claude
Desktop, Claude Code, Cursor, Windsurf, ChatGPT, or Gemini. That client brings
its own language model.

When you ask the assistant a question, the client may send your prompt and the
tool results it receives from this server (for example archive names, coverage
counts, or verify outcomes) to its own provider's service in order to generate a
reply. How that data is handled is governed by **that vendor's privacy policy**,
not by Hiberden. Review the privacy policy of whichever AI client and provider
you choose to connect. Hiberden has no control over, and no visibility into,
what those providers do with the data their model processes.

## Credentials

Cloud storage secrets (for example an AWS S3 access key and secret access key)
are never entered through the AI client and never pass through this server. You
enter them in Hiberden itself: in the desktop application, or on a Linux server
with the `hiberden set-cloud-credential` command. On Windows they are kept in
Credential Manager and on a Mac in your login Keychain; on Linux, Hiberden keeps
them in owner-only files under `~/.hiberden/keys`, or in a `keys` folder beside
the catalog when `HIBERDEN_DB` moves it. The MCP server cannot create cloud
destinations: when asked, it directs you to the desktop app. This is a
deliberate design choice so that secrets are typed into Hiberden directly and
never travel through the AI or agent context.

## Write and configuration tools (off by default)

The default permission level exposes read and verify tools only. Its tools
change nothing about your setup. Besides the outcome of a verification you
asked for (see `verify_copy` above), the server records an audit row for any
call your settings refuse, and it adds an archive written before the per-file
index existed to that index, reading the archive's file list from a local or
NAS copy. Catalog management tools
unlock only when you raise the Access level inside the Hiberden desktop
application (Settings → MCP), in two steps: the Archive level adds
creating projects and Collections, renaming them, and moving archives between
them, and the Full level adds creating local or NAS destinations, retiring
destinations, creating policies, adding or removing policy bindings, and
assigning a policy to a project. Tools that delete catalog entries
(projects, Collections, archives, copy records, destinations, policies)
additionally require a separate delete override in the same settings panel.
The catalog's local audit log records every write the assistant performs and
every attempt your permission settings refuse, together with the permission
level in effect. Deletes are recorded as well, except that connector 1.3.2
leaves no row when it deletes an archive or a copy record. Completed verifications are recorded there too, including at the default
level, naming the algorithm the pass ran. That log stays on your machine like
everything else. Even when enabled, these tools change only your local catalog.
They can create local or NAS destinations but never a cloud one, and they send
nothing to Hiberden or any third party.

## Changes to this policy

We may update this policy as the software changes. Material changes will be
reflected by updating the "Last updated" date at the top of this document.

## Contact

Questions about this policy: support@hiberden.app.

Hosted version of this policy: https://hiberden.app/mcp/privacy.
