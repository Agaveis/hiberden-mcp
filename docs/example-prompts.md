# Hiberden MCP: example prompts

Things an operator can say to an AI assistant (Claude Desktop, Claude Code,
Cursor, Windsurf, ChatGPT, Gemini, and other MCP clients) once the Hiberden MCP
server is connected. The assistant turns plain language into tool calls against
your local archive catalog and reports back.

How to read this page: each entry shows a prompt you can type, the tool(s) it
exercises, and what a good answer looks like. Phrasing is flexible: say it your
own way. The assistant picks the tool, you do not name it.

Two important facts up front:

- **Read-only by default.** Out of the box the server can list, inspect, and
  verify your archives — it cannot change your setup. Catalog-organization
  write tools (projects, Collections, destinations, policies) exist behind an
  opt-in permission level you raise in the Hiberden desktop under
  Settings → MCP, and deletes have their own additional switch; every write is
  audited. Saving bytes to media and restoring always stay in the desktop app.
- **Verify means a real read-back.** When you ask the assistant to prove a copy
  is good, it does not read a stored flag. It re-reads the bytes off the disk,
  NAS, or tape, recomputes the SHA-256, and compares it to the recorded hash. A
  "Verified" answer is proof from a fresh read-back, not a stored flag.

---

## A. Inventory: what do I have?

**"What projects do I have?"**
Tool: `list_projects`. Good answer: every top-level project by name, its
protection policy (or that it has none yet), how many archives it holds, and a
quick coverage roll-up per project (how many archives are fully covered, at risk,
and so on).

**"List everything in the Weddings project."**
Tool: `list_archives` (filtered to that project). Good answer: each archive in
Weddings with its size, SHA-256, 3-2-1 coverage, and a line per copy showing the
destination, the destination kind (disk, NAS, tape, cloud), and that copy's
status.

**"What Collections are inside the Weddings project, and how many archives are in
each?"**
Tool: `list_collections`. Good answer: each Collection in Weddings by name (with its
parent Collection if it is nested) and the number of archives filed directly in it.
Collections are Hiberden's middle tier (Project > Collection > Archive): they organize
the catalog but are never written to media themselves.

**"What's in the 2024 Collection of Weddings?"**
Tools: `list_collections` (to resolve the Collection) then `list_archives` filtered to
that Collection. Good answer: just the archives filed in that Collection, each with its
size and coverage.

**"Find the Johnson family album."**
Tool: `list_archives` with a name filter. Good answer: the archive (or archives)
whose name matches, so you can refer to things by name without knowing an id. The
match is a case-insensitive substring, so "johnson" finds "Johnson-Family-Album".

**"What backup destinations are configured, and which ones are retired?"**
Tool: `list_destinations`. Good answer: every configured destination (tape,
local disk, NAS, cloud) with its name, kind, slot, and whether it is enabled or
retired.

**"Show me the most recent backup activity."**
Tool: `recent_activity`. Good answer: the latest copy activity newest first:
which archive, to which destination, the status, and when it was written or last
verified. Ask for "the last 50" to widen the window.

---

## B. Coverage and risk: am I protected?

**"What is my overall 3-2-1 coverage right now?"**
Tool: `coverage_status`. Good answer: the total archive count and how many sit in
each state: unconfigured, unprotected, in progress, at risk, and fully covered.
This is the headline health number for the whole library.

**"Which archives are NOT yet in three places?"**
Tools: `coverage_status` then `list_archives`. Good answer: the count of archives
that are not fully covered, then the specific archives that are unprotected, in
progress, or at risk, each with how many verified copies it has versus how many
its policy requires.

**"What is at risk? Show me anything I should worry about."**
Tools: `coverage_status` then `list_archives` (or `archive_detail` to drill in).
Good answer: the archives in the "at risk" state called out by name, with why
(for example a copy that failed verification or a copy that has gone missing), so
you know what to act on first.

**"Are there any archives with no protection policy set up at all?"**
Tools: `list_projects` and `list_archives`. Good answer: the projects with no
policy assigned and the archives that land in the "unconfigured" state as a
result, since those are not being protected to any target yet.

---

## C. Drill-down: tell me everything about one archive

**"Show me everything about archive 42."**
Tool: `archive_detail`. Good answer: the full record for that one archive: its
project, size, SHA-256, the legacy MD5 if it was imported with one, its coverage
state, and every copy with the destination, the kind, the status, its address
(disk path, tape serial, or cloud URI), when it was written, and when it was last
verified.

**"Where exactly are the copies of the Johnson family album, and when were they
last checked?"**
Tools: `list_archives` (to find it by name) then `archive_detail`. Good answer:
each copy's destination and address, and its last-verified timestamp, so you can
see whether any copy is overdue for a re-check.

---

## D. Proof and verification: can you prove it is really there?

This is what Hiberden is for. The assistant does not take the catalog's word for
it: it reads the copy back and re-hashes it.

**"Is my Smith wedding shoot backed up to three places, and can you prove the NAS
copy is really there?"**
Tools: `list_archives` or `archive_detail` to confirm the three copies and their
recorded status, then `verify_copy` on the NAS copy. What happens: `verify_copy`
mounts and re-reads that copy off the NAS, recomputes its SHA-256, and compares
it to the archive's recorded hash. On a match it stamps the copy Verified and
reports the proof (the computed hash equals the expected hash, and the byte count
read back). On a mismatch it stamps Failed. If the file is gone it stamps
Missing. Good answer: "Three copies are recorded (disk, NAS, tape). I just read
the NAS copy back: SHA-256 matches the recorded hash over N bytes, so it is
genuinely there and intact, now stamped Verified." If you also ask about the
cloud copy, the assistant will tell you that cloud read-back verification runs in
the Hiberden desktop app, not through the assistant, so it has not passed or
failed here: it was not checked here. That is honesty about scope, not a failure.

**"Re-verify the tape copy of archive 17."**
Tool: `verify_copy` (tape). What happens: the cartridge is mounted and the copy
is read back through the tape path, re-hashed, and compared. Good answer: a clear
Verified or Failed with the computed versus expected SHA-256. (Tape read-back has
been validated on one LTO-9 drive; behavior on other drives and generations is
expected to work but is not broadly proven yet.)

**"Check that the local disk copy of the Garcia engagement gallery still
matches."**
Tool: `verify_copy` (disk). Good answer: the disk copy is re-read and re-hashed;
you get Verified on a match, Failed on a mismatch, or Missing if the file is no
longer at its recorded path.

**"Can you verify the cloud copy of archive 42?"**
Tool: `verify_copy` (cloud destination). Good answer: a plain statement that
cloud read-back verification is done in the Hiberden desktop app rather than
through the assistant, so this copy was not checked here and has neither passed
nor failed. To verify it, open the Hiberden desktop and run Verify on that copy.
This is a deliberate boundary, not an error.

---

## E. Tape questions

**"Which tapes do I have, and when was each one last verified?"**
Tool: `list_tapes`. Good answer: each tape by serial and volume label, its
capacity and how much is used, how many copies live on it, and when it was last
verified, so you can spot a cartridge that has not been checked in a long time.

**"Which tape is getting full?"**
Tool: `list_tapes`. Good answer: each tape's used versus total bytes, with the
ones nearing capacity called out.

**"What's on tape HIB001L9?"** (or "How many archives are on tape serial
LTO000042, and which ones?")
Tool: `tape_detail` (by serial). Good answer: the tape's label, capacity, used
space, and last-verified time, its total copy count, and the list of archives
that have a copy on that cartridge, each by name, project, and size. This turns
"what is on this barcode?" into a real contents list, not just a number.

---

## F. Setup and write actions

Out of the box the assistant cannot change anything. If you raise the LLM
Command Permissions level in the Hiberden desktop (Settings → MCP), it can also
organize the catalog on request — create projects and Collections, move
archives, create destinations and policies, assign policies — and, only with
the separate delete override, remove catalog entries. Every write lands in the
catalog's audit log with the permission level in effect. Saving new archives to
media and restoring files always stay in the desktop app.

---

## G. Reports and deliverables

The catalog holds a per-file index of your archives (paths, sizes, per-file
SHA-256 — built at write time, or backfilled from a local copy for older
archives), so the assistant can produce any report format you can describe.
There is no separate export feature to wait for: the AI client is the export
feature. One honest limit: an archive imported from a legacy tape library with
no local copy has no per-file index, and the assistant will say the manifest is
unavailable rather than pretend the archive is empty.

**"Make me a client-ready manifest of the Q3_Masters archive with per-file
checksums."**
Tools: `archive_detail` + `list_archive_files`. Good answer: a formatted
manifest (markdown table, CSV, or print-ready text — whatever you asked for)
listing every file with its size and SHA-256, plus the archive-level hash and
where its verified copies live.

**"How much am I storing, and where?"**
Tool: `catalog_stats`. Good answer: totals (projects, archives, bytes), stored
copies by status, destinations by kind, and tape capacity against use — ready
to paste into a status report.

**"Build an insurance schedule: every archive, its size, hash, and the media
it sits on."**
Tools: `list_archives`, plus `list_archive_files` per archive when file-level
detail is wanted. Good answer: a structured schedule in your template.

---

## H. Jobs: did my backups run?

**"Did last night's save finish?"**
Tool: `list_jobs`. Good answer: the most recent jobs with verb, state, bytes,
and timestamps, read back in plain language ("the save to your cloud
destination finished at 02:14 and verified; nothing is still running").

**"Why did the upload fail?"**
Tool: `list_jobs`. Good answer: the failed job's recorded failure reason,
quoted, and what to do next (resume or retry from the desktop, check the
destination).

---

## Notes

- The assistant chooses the tool from what you ask; you never have to name a tool
  or pass an id by hand. If it needs an id (for example which destination to
  verify), it will look it up first or ask.
- The server reads from a single local SQLite catalog shared with the Hiberden
  desktop app and CLI. It opens the catalog only for the moment of each call, so
  the desktop and the assistant can run at the same time.
- The server does no network I/O on its own. At the default read-only level the
  only tool that writes anything is `verify_copy`, and it only ever stamps a
  status after a genuine read-back; the opt-in write levels are described in
  section F.
