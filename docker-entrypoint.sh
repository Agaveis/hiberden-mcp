#!/bin/sh
# The connector opens its SQLite catalog at startup and exits 1 if it cannot.
# SQLite creates the database FILE but never its parent DIRECTORY, so a missing
# parent fails the process before it answers a single JSON-RPC request.
#
# Two traps this guards against, both of which a sandbox will hit and a root
# build-time test will not:
#   1. `mkdir -p` SUCCEEDS when the directory already exists but is not writable
#      by the current uid, so its exit status cannot be trusted on its own.
#   2. Registries may run the image as `nobody` or an arbitrary uid, or with a
#      read-only rootfs. Fall back to /tmp in that case.
#
# Deliberately no `:` redirection probe here. `:` is a POSIX special builtin, so
# a failed redirection on it exits the shell immediately even inside an `if`.
set -e

: "${HIBERDEN_DB:=/var/lib/hiberden/catalog.db}"
db_dir=$(dirname "$HIBERDEN_DB")

mkdir -p "$db_dir" 2>/dev/null || true

# SQLite needs to create -wal and -shm siblings next to the database, so the
# DIRECTORY has to be writable, not merely present.
if [ ! -w "$db_dir" ]; then
    HIBERDEN_DB=/tmp/hiberden/catalog.db
    db_dir=/tmp/hiberden
    mkdir -p "$db_dir"
fi

export HIBERDEN_DB
exec /usr/local/bin/hiberden-mcp "$@"
