"""Real focused VS Code minute -> HTTP backend -> Swift inbox/proof/rewards.

Generated fixture tokens stay in process environment/isolated SecretStorage.
No personal workspace, credential, provider or account is used.
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import threading
from proxy import BoundedHTTPServer, Handler, list_events

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--client', required=True)
    args = parser.parse_args()
    if not Path(args.client).is_file():
        parser.error('Build ForgeIntegrationCheck and pass its actual executable path')
    extension = Path(__file__).resolve().parent.parent / 'Integrations' / 'VSCode'
    with tempfile.TemporaryDirectory(prefix='forge-host-chain-') as directory:
        root = Path(directory)
        for name in ('workspace', 'user', 'extensions'):
            (root/name).mkdir(mode=0o700)
        client, ingest = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
        database = str(root/'events.sqlite')
        os.environ.update(FORGE_PROXY_TOKEN=client, FORGE_INGEST_TOKEN=ingest, FORGE_AI_MODE='local', FORGE_EVENT_DB=database)
        server = BoundedHTTPServer(('127.0.0.1', 0), Handler)
        worker = threading.Thread(target=server.serve_forever)
        worker.start()
        base = f'http://127.0.0.1:{server.server_port}'
        environment = dict(os.environ, FORGE_HOST_CHAIN='1', FORGE_HOST_RESULT=str(root/'result.json'), FORGE_HOST_CODING_URL=base+'/v1/events/coding', FORGE_HOST_EVENTS_URL=base+'/v1/events?cursor=0', FORGE_HOST_INGEST_TOKEN=ingest, FORGE_HOST_CLIENT_TOKEN=client, FORGE_FIXTURE_URL=base, FORGE_FIXTURE_TOKEN=client)
        try:
            subprocess.run(['code', '--wait', '--user-data-dir', str(root/'user'), '--extensions-dir', str(root/'extensions'), '--extensionDevelopmentPath='+str(extension), '--extensionTestsPath='+str(extension/'host-test'), '--skip-welcome', '--skip-release-notes', '--disable-workspace-trust', str(root/'workspace')], env=environment, check=True, timeout=300)
            result = json.loads((root/'result.json').read_text())
            if result['status']!='passed':
                raise RuntimeError('Isolated host check failed: '+result.get('message','unknown fixture failure'))
            assert result['focusedMinute']
            page = list_events(database)
            assert len(page['events']) == 1 and page['events'][0]['minutes'] == 1
            subprocess.run([args.client], env=environment, check=True, timeout=60)
            print('FORGE real VS Code minute -> HTTP -> Swift evidence -> manual quest proof/rewards chain passed; fixture storage erased.')
        finally:
            server.shutdown(); server.server_close(); worker.join()

if __name__ == '__main__':
    main()
