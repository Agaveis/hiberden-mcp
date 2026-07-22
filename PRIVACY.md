# Hiberden MCP Server: Privacy Policy

**Last updated:** 2026-07-21

## Summary

The Hiberden MCP server runs entirely on your own computer. It reads your local
Hiberden archive catalog so an AI assistant you have connected (for example
Claude Desktop, Claude Code, or Cursor) can answer plain-language questions about
your archives and verify your copies. The server sends nothing to Hiberden and
nothing to any other company. There is no account, no sign-up, no telemetry, and
no cloud upload performed by this server. Your catalog and your files stay on
your machine and on the storage you already control.

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
  `%LOCALAPPDATA%\Hiberden\catalog.db`. This is the same SQLite database the
  desktop app and command-line tool use. It contains your projects, Collections,
  archives, destinations, tapes, copy records, the per-file index of each
  archive (relative file paths, sizes, and per-file hashes), background job
  records (including recorded failure text, which can mention file paths and
  storage locations), a local audit log of assistant actions, sizes, SHA-256
  hashes, status fields, and timestamps. The database is opened only for the
  duration of each tool call.
- **Local disk and NAS file contents during a verify.** When you (through the
  assistant) run `verify_copy` on a disk or NAS copy, the server re-reads that
  copy from the local file system or the network share and re-hashes it. In the
  default `full` mode it compares against the recorded SHA-256, the recorded
  BLAKE3, and the stored signature when one is present; in `fast` mode it
  re-reads the same bytes and compares against the recorded BLAKE3 only. Either
  way the file is read locally; the contents are not transmitted anywhere.
- **Tape contents during a verify.** When you run `verify_copy` on a tape copy,
  the server mounts the cartridge and reads the copy back from tape to re-hash
  it. As with disk and NAS, the data is read locally and is not transmitted.

The server returns only catalog facts and verify results (for example a status
of Verified, Failed, or Missing, together with which hash algorithm the pass
ran) to the connected AI client over the local stdio channel. It does not
return raw file contents.

## What the server does NOT do

- **No telemetry.** The server collects no usage data and reports nothing about
  how, when, or whether you use it.
- **No analytics.** There is no measurement, profiling, or behavioral tracking.
- **No phone-home.** In its default read-and-verify mode the server performs
  zero network input or output. Even with write tools enabled (see below) it
  only touches the local catalog and creates local or NAS destinations; it never
  contacts Hiberden or any third party.
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
enter them in the Hiberden desktop application, which stores them in your
operating system's secure credential store (the OS keyring). The MCP server
cannot create cloud destinations: when asked, it directs you to the desktop app.
This is a deliberate design choice so that secrets are typed directly into the
operating system and never travel through the AI or agent context.

## Write and configuration tools (off by default)

The default permission level exposes read and verify tools only. It changes
nothing about your setup; the only state it writes is the outcome of a
verification you asked for (see `verify_copy` above). Catalog management tools
unlock only when you raise the LLM Command Permissions level inside the Hiberden
desktop application (Settings → MCP), in two steps: the Archive level adds
creating projects and Collections, renaming them, and moving archives between
them, and the Full level adds creating local or NAS destinations, retiring
destinations, creating policies, adding or removing policy bindings, and
assigning a policy to a project. Tools that delete catalog entries
(projects, Collections, archives, copy records, destinations, policies)
additionally require a separate delete override in the same settings panel.
Every write or delete the assistant performs — and every refused attempt — is
recorded in the catalog's local audit log together with the permission level in
effect. Completed verifications are recorded there too, including at the default
level, naming the algorithm the pass ran. That log stays on your machine like
everything else. Even when enabled, these tools act only on your local catalog
and local or NAS destinations. They
do not create cloud destinations and they send nothing to Hiberden or any third
party.

## Changes to this policy

We may update this policy as the software changes. Material changes will be
reflected by updating the "Last updated" date at the top of this document.

## Contact

Questions about this policy: support@hiberden.app.

Hosted version of this policy: https://hiberden.app/mcp/privacy.
