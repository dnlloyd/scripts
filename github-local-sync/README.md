# GitHub local sync

A simple extra backup of local project folders, including projects that aren't
stored on GitHub. The script copies directories from `/Users/dan/github` into
`/Users/dan/Documents/github-sync` using macOS's built-in `rsync` and `/bin/sh`.
If Documents is synced with iCloud Drive, the destination is also synced to iCloud.

## What gets backed up

The script copies each non-hidden directory directly inside the source, retaining
its directory name at the destination. For example, `github/dnlloyd` becomes
`github-sync/dnlloyd`. Hidden files and directories inside those directories are
included unless excluded below. Files directly inside the source are not copied.

These names are excluded at every depth:

- `.git`
- `node_modules/`
- `.terraform*` (including `.terraform.lock.hcl`)
- `terraform.tfstate*`

This is a supplemental file backup. It does not preserve Git history or all file
metadata, and the current rsync options do not copy symbolic links. It updates
existing files but does not delete destination files when their source disappears.
Adding an exclusion also leaves any previously backed-up copies in place.

The `-t` option preserves modification times so subsequent runs can skip files
whose size and modification time match. The first run after enabling it may
recopy files to bring existing backups' timestamps into sync.

## Run manually

```sh
mkdir -p /Users/dan/Documents/github-sync
/bin/sh /Users/dan/github/dnlloyd/scripts/github-local-sync/github-sync.sh
```

To use different locations, edit `GITHUB_SRC_PATH` and `SYNC_DEST` in
[`github-sync.sh`](github-sync.sh). Also update the absolute script and log paths
in the cron entry below if your username or project location differs.

## Schedule with cron

The schedule below runs every day at **noon, local time**. The Mac must be awake
at noon. Cron skips runs missed while the Mac is asleep or powered off and does
not catch up when it wakes. Being plugged in does not guarantee that a laptop
with its lid closed stays awake.

### Allow access to Documents

macOS protects Documents and iCloud Drive. For this scheduled backup, grant
Full Disk Access to `/usr/sbin/cron`:

1. Open **System Settings > Privacy & Security > Full Disk Access**.
2. Click **+** and authenticate if prompted.
3. In the file picker, press **Command-Shift-G**, enter `/usr/sbin`, and select
   `cron`.
4. Add it and ensure its switch is enabled.

This grants access to jobs launched through cron, including other cron jobs;
it is not a permission limited to this script. See this
[Apple Developer Forums report of the rsync fix](https://developer.apple.com/forums/thread/126497).

### Install the schedule

Run these commands in Terminal to prepare the folders and edit your user's
crontab. No `sudo` is needed.

```sh
mkdir -p ~/Library/Logs /Users/dan/Documents/github-sync
crontab -e
```

Add this single line, or replace an existing entry for this script, then save
and exit the editor:

```cron
0 12 * * * /bin/sh /Users/dan/github/dnlloyd/scripts/github-local-sync/github-sync.sh >> /Users/dan/Library/Logs/github-sync.log 2>&1
```

The first two fields specify minute `0` and hour `12`; the three `*` fields
mean every day of the month, every month, and every day of the week. The
redirection appends standard output and errors to the log.

### Test and inspect

Confirm the installed schedule:

```sh
crontab -l
```

After a scheduled run, inspect the latest output:

```sh
tail -n 40 ~/Library/Logs/github-sync.log
```

To test cron without waiting until noon, temporarily replace `0 12 * * *` with
`* * * * *`. Keep the Mac awake, wait for a run, and inspect the log. Restore the
noon schedule immediately afterward; the temporary schedule runs every minute
and can start overlapping backups if a run takes longer than a minute.

The manual command above tests the script, but a successful Terminal run does
not verify cron's access to Documents.

### Troubleshoot Documents access

If the job starts but `tee` and `rsync` report `Operation not permitted` for
`/Users/dan/Documents/github-sync`, macOS privacy controls may be denying the
cron job access to Documents. Check that `/usr/sbin/cron` is enabled under Full
Disk Access. Terminal's access does not automatically give cron access. Changing
ordinary file permissions with `chmod` does not grant macOS privacy access.
See [Apple's file access documentation](https://support.apple.com/guide/security/secddd1d86a6/web).

After correcting permissions, inspect the next run's output. Earlier failures
remain in the appended log.

### Logs

- `~/Library/Logs/github-sync.log` receives the scheduled job's standard output
  and errors, including rsync output.
- `/Users/dan/Documents/github-sync/sync.log` receives the date and directory
  progress messages from the script, including manual runs.

Both logs append over time and have no automatic rotation. The cron output log
is outside the source tree, so this script does not back it up.

### Update or remove the schedule

```sh
crontab -e
```

Edit or remove only the line for `github-sync.sh`, then save and exit. Changes
take effect automatically. Changes to the script itself take effect on the next
run. Removing the entry leaves the script, backups, and logs in place.
