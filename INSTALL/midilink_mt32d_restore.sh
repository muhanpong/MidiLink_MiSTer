#!/bin/bash
# Restore midilink / mt32d from a backup made by midilink_mt32d_install.sh.
#
# usage: midilink_mt32d_restore.sh            restore the newest backup
#        midilink_mt32d_restore.sh <dir>      restore from a specific backup dir
#        midilink_mt32d_restore.sh list       list available backups
#
# Running midilink/mt32d processes are not touched; re-select the UART
# MIDI mode in the MiSTer menu (or reboot) to start the restored binaries.

SBIN=${SBIN:-/usr/sbin}
BACKUP_BASE=${BACKUP_BASE:-/media/fat/linux}
FILES="midilink mt32d"

die() { echo "ERROR: $*" >&2; exit 1; }

list_backups() {
	ls -1d "$BACKUP_BASE"/backup_midilink_* 2>/dev/null | sort
}

if [ "$1" = "list" ]; then
	list_backups | while read -r d; do
		echo "$d"
		for f in $FILES; do
			[ -f "$d/$f" ] && echo "    $(md5sum "$d/$f" | cut -c1-32)  $f"
		done
	done
	exit 0
fi

if [ -n "$1" ]; then
	SRC=$1
else
	SRC=$(list_backups | tail -n 1)
	[ -n "$SRC" ] || die "no backup found in $BACKUP_BASE (backup_midilink_*)"
fi
[ -d "$SRC" ] || die "backup dir not found: $SRC"
[ -w "$SBIN" ] || die "$SBIN is not writable (run as root)"
for c in install cmp md5sum; do
	command -v $c >/dev/null || die "missing tool: $c"
done

echo "Restoring from: $SRC"
restored=0
for f in $FILES; do
	if [ ! -f "$SRC/$f" ]; then
		echo "  $f: not in backup, skipped"
		continue
	fi
	# install writes a new inode, so a running process keeps its old file
	install -m 755 "$SRC/$f" "$SBIN/$f" || die "failed to restore $f"
	if cmp -s "$SRC/$f" "$SBIN/$f"; then
		echo "  $f: restored ($(md5sum "$SBIN/$f" | cut -c1-32))"
		restored=$((restored + 1))
	else
		die "$f: verification failed after copy"
	fi
done
sync

[ $restored -gt 0 ] || die "nothing restored"
echo "Done. Re-select the UART MIDI mode in the MiSTer menu (or reboot) to use the restored files."
