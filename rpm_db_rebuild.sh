#!/usr/bin/env bash

# Rebuild the RPM database

sudo ls -la /var/lib/rpm/__db* 2>/dev/null || true
sudo rm -f /var/lib/rpm/__db* 2>/dev/null || true

# 

sudo mkdir -p /var/lib/rpm/backup.$(date +%F_%H%M%S)
sudo cp -a /var/lib/rpm/* /var/lib/rpm/backup.$(date +%F_%H%M%S)/

sudo rpm --rebuilddb

# 

sudo db_verify /var/lib/rpm/Packages 2>/dev/null || true
