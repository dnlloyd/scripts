#!/usr/bin/env bash

# Find all RPM-related processes and terminate them safely.

echo "Searching for RPM processes..."
PIDS=$(pgrep -f 'rpm|rpmq|rpmdb')

if [[ -z "$PIDS" ]]; then
    echo "No RPM processes found."
    exit 0
fi

echo "Found RPM processes:"
ps -fp $PIDS

echo "Attempting graceful termination..."
kill $PIDS 2>/dev/null

# Give them a moment
sleep 2

# Check what survived
HANGERS=$(pgrep -f 'rpm|rpmq|rpmdb')

if [[ -n "$HANGERS" ]]; then
    echo "Forcing termination on stubborn processes:"
    ps -fp $HANGERS
    kill -9 $HANGERS 2>/dev/null
else
    echo "All RPM processes terminated cleanly."
fi

echo "Cleanup complete."
