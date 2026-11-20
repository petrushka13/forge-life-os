'use strict';
const vscode = require('vscode'), crypto = require('node:crypto');
const {endpoint, sample} = require('./activity');
const {EvidenceQueue} = require('./queue');
function activate(context) {
  let enabled=false, lastEdit=0, previous=Date.now(), project='';
  const salt=context.globalState.get('identitySalt',crypto.randomUUID());
  context.globalState.update('identitySalt',salt);
  const status=vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right,5);
  const queue=new EvidenceQueue({events:context.globalState.get('pending',[]),persist:events=>context.globalState.update('pending',events),send:async(event,signal)=>{
    if (!vscode.workspace.isTrusted) return false;
    const value=context.globalState.get('endpoint'), token=await context.secrets.get('ingest-token');
    if (!value || !token || signal.aborted) return false;
    const url=endpoint(value);
    const response=await fetch(url,{method:'POST',redirect:'error',signal:AbortSignal.any([signal,AbortSignal.timeout(10000)]),headers:{'Content-Type':'application/json',Authorization:`Bearer ${token}`},body:JSON.stringify(event)});
    if (response.status!==200) return false;
    const text=await response.text(); if(text.length>4096) return false;
    return JSON.parse(text).recorded===true;
  }});
  function display() { status.text=`$(flame) FORGE ${enabled?'recording':'paused'} · ${queue.events.length} pending${queue.dropped?' · queue full':''}`; status.show(); }
  function stop() { enabled=false; lastEdit=0; project=''; previous=Date.now(); queue.stop(); display(); }
  status.command='forge.stop'; status.tooltip='Opt-in active coding minutes only. Click to stop and cancel delivery. No source, keys or paths are collected.';
  context.subscriptions.push(status);
  const command=(id,action)=>context.subscriptions.push(vscode.commands.registerCommand(id,action));
  command('forge.configure',async()=>{
    const value=await vscode.window.showInputBox({prompt:'Private HTTPS endpoint ending /v1/events/coding',value:context.globalState.get('endpoint','http://127.0.0.1:8787/v1/events/coding')});
    if (!value) return;
    try {
      const url=endpoint(value),token=await vscode.window.showInputBox({prompt:'Dedicated ingest token (32 random bytes; SecretStorage)',password:true});
      if (!token) return;
      if (token.length<43) throw new Error();
      stop(); await context.secrets.store('ingest-token',token); await context.globalState.update('endpoint',url);
      vscode.window.showInformationMessage('FORGE configured. Start recording explicitly in a trusted workspace.');
    } catch { vscode.window.showErrorMessage('Configuration failed. Use HTTPS /v1/events/coding and a secure ingest token.'); }
  });
  command('forge.start',()=>{ if(!vscode.workspace.isTrusted)return; enabled=true;lastEdit=0;previous=Date.now();display(); });
  command('forge.stop',stop);
  command('forge.flush',async()=>{ await queue.flush();display(); });
  command('forge.erase',async()=>{ stop();await queue.erase();await context.globalState.update('endpoint',undefined);await context.secrets.delete('ingest-token');display(); });
  context.subscriptions.push(vscode.window.onDidChangeWindowState(()=>{lastEdit=0;previous=Date.now();}));
  context.subscriptions.push(vscode.workspace.onDidChangeTextDocument(event=>{
    if (!enabled || !vscode.window.state.focused || !vscode.workspace.isTrusted || event.document.uri.scheme!=='file')return;
    const folder=vscode.workspace.getWorkspaceFolder(event.document.uri);
    if (folder) { project='workspace-'+crypto.createHmac('sha256',salt).update(folder.uri.toString()).digest('hex').slice(0,20);lastEdit=Date.now(); }
    // Do not inspect text, contentChanges, selections, clipboard or keystrokes.
  }));
  const timer=setInterval(async()=>{
    const now=Date.now();
    if (enabled) {
      const event=sample({now,lastEdit,focused:vscode.window.state.focused,trusted:vscode.workspace.isTrusted,project,previous});
      if (event) await queue.add(event);
      await queue.flush();display();
    }
    previous=now;
  },60000);
  context.subscriptions.push({dispose:()=>{clearInterval(timer);stop();}});
  display();
  // Available only in VS Code's isolated test host, never installed production mode.
  if (context.extensionMode===vscode.ExtensionMode.Test && process.env.FORGE_HOST_CHAIN==='1') return {
    async configureFixture(value,token) {
      const url=endpoint(value); if(token.length<43) throw new Error('Invalid fixture credential');
      stop();await context.secrets.store('ingest-token',token);await context.globalState.update('endpoint',url);
    }
  };
}
module.exports={activate};
