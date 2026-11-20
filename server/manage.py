"""Offline SQLite backup/restore. Stop the server before restore."""
import argparse
from contextlib import closing
import os
import sqlite3
from pathlib import Path

def backup(source, destination):
    destination = Path(destination)
    temporary = destination.with_suffix(destination.suffix + '.temporary')
    with closing(sqlite3.connect(f'file:{Path(source).resolve()}?mode=ro', uri=True)) as src, closing(sqlite3.connect(temporary)) as dst:
        src.backup(dst)
        dst.execute("PRAGMA journal_mode=DELETE")
        if dst.execute('PRAGMA integrity_check').fetchone()[0] != 'ok': raise ValueError('Backup failed integrity check')
    os.chmod(temporary, 0o600)
    os.replace(temporary, destination)

def restore(source, destination):
    with closing(sqlite3.connect(f'file:{Path(source).resolve()}?mode=ro', uri=True)) as db:
        if db.execute('PRAGMA integrity_check').fetchone()[0] != 'ok' or db.execute('PRAGMA user_version').fetchone()[0] != 1: raise ValueError('Invalid event backup')
        db.execute('SELECT id, payload, received FROM events LIMIT 1')
        db.execute("SELECT value FROM metadata WHERE name='serverID'")
    destination = Path(destination)
    if destination.exists(): backup(destination, destination.with_suffix('.pre-restore.sqlite'))
    for suffix in ['-wal', '-shm']:
        path = Path(str(destination)+suffix)
        if path.exists(): raise ValueError('Stop the server and close all database connections before restoring')
    backup(source, destination)

if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('action', choices=['backup','restore']); parser.add_argument('source'); parser.add_argument('destination'); parser.add_argument('--confirm-server-stopped', action='store_true'); args=parser.parse_args()
    if args.action == 'restore' and not args.confirm_server_stopped: parser.error('Restore requires --confirm-server-stopped')
    (backup if args.action == 'backup' else restore)(args.source,args.destination)
    print('Database operation completed; file contents were not logged.')
