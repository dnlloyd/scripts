#!/usr/bin/env bash

# Rebuild the RPM database

ls -la /var/lib/rpm/__db* 2>/dev/null || true
rm -f /var/lib/rpm/__db* 2>/dev/null || true

# 

mkdir -p /var/lib/rpm/backup.$(date +%F_%H%M%S)
cp -a /var/lib/rpm/* /var/lib/rpm/backup.$(date +%F_%H%M%S)/

rpm --rebuilddb

# 

db_verify /var/lib/rpm/Packages 2>/dev/null || true
