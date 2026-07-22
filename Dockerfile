# Hiberden MCP connector, containerised.
#
# What this is for
# ----------------
# MCP directory registries build a connector in a Linux sandbox and run an MCP
# introspection handshake (initialize, then tools/list) against it to capture
# the tool surface. This image exists to make that check pass and to let anyone
# inspect the advertised tool surface without installing anything.
#
# What it is NOT
# --------------
# This is not how you run Hiberden. The connector reads a local Hiberden catalog
# (SQLite) that the Hiberden application writes. In this image the catalog is
# empty, so the connector starts, reports itself, and advertises the read-only
# tool surface, but there are no archives to answer questions about. For real
# use, install Hiberden: https://hiberden.app
#
# Point it at a real catalog by mounting one and setting HIBERDEN_DB, e.g.
#   docker run --rm -i -v /var/lib/hiberden:/cat \
#     -e HIBERDEN_DB=/cat/catalog.db hiberden-mcp
# The connector opens it READ-ONLY apart from verify's status writes, and never
# reads the OS keyring.
#
# The binary is fetched rather than built: the connector's source lives in a
# private workspace alongside the archive engine and is not published here.

FROM debian:bookworm-slim

# ca-certificates is not needed for the stdio handshake itself; it is included so
# that cloud-adjacent code paths behave normally if a real catalog is mounted.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ARG HIBERDEN_MCP_VERSION=1.2.1
ADD --chmod=0755 \
    https://github.com/Agaveis/hiberden-mcp/releases/download/v${HIBERDEN_MCP_VERSION}/hiberden-mcp-x86_64-unknown-linux-gnu \
    /usr/local/bin/hiberden-mcp

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

# Default catalog location inside the container. The entrypoint creates the
# parent directory before starting: the connector opens the catalog at startup
# and SQLite will NOT create a missing parent, so without this the process exits
# 1 with "unable to open database file" before answering a single request.
ENV HIBERDEN_DB=/var/lib/hiberden/catalog.db

# Build-time smoke test. This fails the image build if the connector can no
# longer complete an MCP handshake, which is exactly what a directory sandbox
# checks. An empty catalog is created and migrated on open, and the permission
# tier defaults to ReadOnly, so only read and verify tools are advertised.
# 0777 because the image may be run as `nobody` (below) or as an arbitrary uid
# by a sandbox. Without it the connector cannot create the catalog and exits
# before answering, which reads as a broken server rather than a permissions
# problem. The entrypoint still falls back to /tmp if this path is unusable.
RUN mkdir -p /var/lib/hiberden \
 && chmod 0777 /var/lib/hiberden \
 && printf '%s\n%s\n' \
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{}}}' \
      '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
    | /usr/local/bin/hiberden-mcp > /tmp/probe.jsonl \
 && grep -q '"serverInfo"' /tmp/probe.jsonl \
 && grep -q '"name":"verify_copy"' /tmp/probe.jsonl \
 && rm -f /tmp/probe.jsonl /var/lib/hiberden/catalog.db*

# Runs unprivileged. The entrypoint falls back to a writable path if the
# configured catalog directory cannot be created (read-only rootfs, or a
# sandbox that runs the image as an arbitrary uid).
USER nobody

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
