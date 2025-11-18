#!/bin/sh
echo "[offline-worker] Starting with no network..."
echo "[offline-worker] Listing /logs contents:"
ls -l /logs || echo "No /logs directory mounted."

echo "[offline-worker] Sleeping for an hour so you can inspect me."
sleep 3600

