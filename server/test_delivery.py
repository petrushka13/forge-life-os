import concurrent.futures
import json
import os
import secrets
import sqlite3
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import patch
from proxy import BoundedHTTPServer, Handler, record_event, list_events, validate_configuration, EventConflict
from manage import backup, restore

class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.database = str(Path(self.temp.name)/'events.sqlite')
        self.client=secrets.token_urlsafe(32); self.ingest=secrets.token_urlsafe(32)
        self.env=patch.dict(os.environ, {'FORGE_PROXY_TOKEN':self.client,'FORGE_INGEST_TOKEN':self.ingest,'FORGE_EVENT_DB':self.database,'FORGE_AI_MODE':'local'})
        self.env.start(); Handler.limits.clear()
    def tearDown(self): self.env.stop(); self.temp.cleanup()
    def event(self,i=0): return {'id':str(i),'kind':'automation_deployed','project':'private-label','timestamp':'2026-10-06T00:00:00Z'}
    def test_durable_pagination_reset_and_backup(self):
        # 10k+ events in a single durable transaction simulates a 90-day backlog.
        record_event(self.event(),self.database)
        with sqlite3.connect(self.database) as db:
            db.executemany('INSERT INTO events VALUES (?, ?, ?)', [(str(i),json.dumps(self.event(i)),time.time()) for i in range(1,10051)])
        cursor=0; identity=None; total=0
        while True:
            page=list_events(self.database,cursor,server_id=identity); identity=page['serverID']; cursor=page['nextCursor']; total+=len(page['events'])
            if not page['hasMore']: break
        self.assertEqual(total,10051); self.assertEqual(list_events(self.database,cursor,server_id=identity)['events'],[])
        target=str(Path(self.temp.name)/'copy.sqlite'); backup(self.database,target)
        restored=str(Path(self.temp.name)/'restored.sqlite'); restore(target,restored)
        self.assertEqual(list_events(restored,0)['serverID'],identity)
        other=str(Path(self.temp.name)/'fresh.sqlite'); record_event(self.event(20000),other)
        self.assertEqual(len(list_events(other,cursor,server_id=identity)['events']),1)
    def test_changed_id_conflict_and_coding_contract(self):
        record_event(self.event(),self.database); changed=self.event(); changed['project']='changed'
        with self.assertRaises(EventConflict): record_event(changed,self.database)
        coding={'id':'coding','kind':'coding_session','project':'label','timestamp':'2026-10-06T10:00:00Z','start':'2026-10-06T09:00:00Z','end':'2026-10-06T10:00:00Z','minutes':1}
        record_event(coding,self.database)
        self.assertEqual(list_events(self.database)['events'][-1]['minutes'],1)
        coding['minutes']=61
        with self.assertRaises(ValueError): record_event(coding,self.database)
    def test_http_auth_readiness_ingest_retry_and_local_ai(self):
        server=BoundedHTTPServer(('127.0.0.1',0),Handler); thread=threading.Thread(target=server.serve_forever);thread.start()
        base=f'http://127.0.0.1:{server.server_port}'
        def request(path,token=None,body=None):
            headers={'Content-Type':'application/json'}
            if token:headers['Authorization']='Bearer '+token
            req=urllib.request.Request(base+path,headers=headers,data=None if body is None else json.dumps(body).encode())
            try:
                with urllib.request.urlopen(req,timeout=5) as response:return response.status,json.load(response)
            except urllib.error.HTTPError as error:return error.code,json.load(error)
        try:
            self.assertEqual(request('/ready')[0],401)
            self.assertEqual(request('/ready',self.client)[0],200)
            self.assertEqual(request('/v1/events/n8n',self.client,self.event())[0],401)
            for _ in range(2):self.assertEqual(request('/v1/events/n8n',self.ingest,self.event())[0],200)
            event=self.event();event['project']='changed';self.assertEqual(request('/v1/events/n8n',self.ingest,event)[0],409)
            page=request('/v1/events?cursor=0',self.client)[1];self.assertEqual(len(page['events']),1)
            plan=request('/v1/plan',self.client,{'action':'dailyPlan','context':{'availableMinutes':0}})
            self.assertEqual(plan[0],200);self.assertEqual(plan[1]['quests'],[])
            self.assertEqual(request('/v1/plan',self.client,{'action':'dailyPlan','context':{'entireDatabase':[]}})[0],400)
            for _ in range(11): status,_=request('/v1/plan',self.client,{'action':'weeklySummary','context':{}})
            self.assertEqual(status,429)
        finally:server.shutdown();server.server_close();thread.join()
    def test_configuration_requires_independent_entropy(self):
        validate_configuration()
        with patch.dict(os.environ,{'FORGE_PROXY_TOKEN':'x'*64}):
            with self.assertRaises(ValueError):validate_configuration()
