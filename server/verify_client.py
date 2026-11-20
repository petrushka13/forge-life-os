"""Real Swift client -> isolated HTTP backend. Never uses personal credentials/data."""
import argparse
import datetime
import os
import secrets
import subprocess
import tempfile
import threading
from pathlib import Path
from proxy import BoundedHTTPServer, Handler, record_event

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--client', required=True); args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='forge-client-backend-') as directory:
        token = secrets.token_urlsafe(32)
        os.environ.update(FORGE_PROXY_TOKEN=token, FORGE_INGEST_TOKEN=secrets.token_urlsafe(32), FORGE_AI_MODE='local', FORGE_EVENT_DB=str(Path(directory)/'events.sqlite'))
        record_event({'id':'client-fixture','kind':'automation_deployed','project':'opaque-fixture','timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat()}, os.environ['FORGE_EVENT_DB'])
        server = BoundedHTTPServer(('127.0.0.1',0), Handler)
        thread = threading.Thread(target=server.serve_forever); thread.start()
        try:
            environment = dict(os.environ, FORGE_FIXTURE_URL=f'http://127.0.0.1:{server.server_port}', FORGE_FIXTURE_TOKEN=token)
            subprocess.run([args.client], env=environment, check=True, timeout=60)
        finally:
            server.shutdown(); server.server_close(); thread.join()

if __name__ == '__main__': main()
