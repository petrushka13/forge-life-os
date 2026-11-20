'use strict';
const assert=require('node:assert/strict');
const vscode=require('vscode');
async function run() {
  const extension=vscode.extensions.getExtension('forge-personal.forge-private-activity');
  assert.ok(extension,'Extension must be discoverable in the real Extension Host');
  const api=await extension.activate();assert.equal(extension.isActive,true);
  const commands=await vscode.commands.getCommands(true);
  for (const command of ['forge.configure','forge.start','forge.stop','forge.flush','forge.erase']) assert.ok(commands.includes(command));
  await vscode.commands.executeCommand('forge.start');
  await vscode.commands.executeCommand('forge.stop');
  await vscode.commands.executeCommand('forge.flush'); // No token/config: safe no-op.
  let focusedMinute=false;
  if(process.env.FORGE_HOST_CHAIN==='1') {
    assert.ok(api?.configureFixture);assert.equal(vscode.workspace.isTrusted,true);
    await api.configureFixture(process.env.FORGE_HOST_CODING_URL,process.env.FORGE_HOST_INGEST_TOKEN);
    const folder=vscode.workspace.workspaceFolders[0];
    const uri=vscode.Uri.joinPath(folder.uri,'synthetic-acceptance.txt');
    await vscode.workspace.fs.writeFile(uri,Buffer.from('FORGE_HOST_PRIVATE_SENTINEL'));
    const document=await vscode.workspace.openTextDocument(uri);
    await vscode.window.showTextDocument(document);
    await vscode.commands.executeCommand('workbench.action.focusActiveEditorGroup');
    await vscode.commands.executeCommand('forge.start');
    const started=Date.now();
    while(Date.now()-started<210000) {
      await new Promise(resolve=>setTimeout(resolve,2000));
      if(!vscode.window.state.focused) continue; // Wait for the actual isolated window; never synthesize focus.
      const edit=new vscode.WorkspaceEdit();edit.insert(uri,new vscode.Position(0,0),'x');assert.equal(await vscode.workspace.applyEdit(edit),true);
      const response=await fetch(process.env.FORGE_HOST_EVENTS_URL,{headers:{Authorization:`Bearer ${process.env.FORGE_HOST_CLIENT_TOKEN}`}});
      if(response.status!==200) throw new Error('Fixture inbox HTTP '+response.status+' '+(await response.json()).error);
      const page=await response.json();
      if(page.events.length) {
        assert.equal(page.events.length,1);const event=page.events[0];
        assert.equal(event.kind,'coding_session');assert.equal(event.minutes,1);assert.match(event.project,/^workspace-[a-f0-9]{20}$/);
        assert.ok(!JSON.stringify(event).includes('SENTINEL'));assert.ok(!JSON.stringify(event).includes(folder.uri.fsPath));
        focusedMinute=true;break;
      }
    }
    assert.equal(focusedMinute,true,'A real one-minute timer tick must reach the actual backend');
    await vscode.commands.executeCommand('forge.stop');
  }
  await vscode.commands.executeCommand('forge.erase'); // Isolated --user-data-dir only.
  if (process.env.FORGE_HOST_RESULT) require('node:fs').writeFileSync(process.env.FORGE_HOST_RESULT,JSON.stringify({status:'passed',activation:true,commands:5,stop:true,noTokenFlush:true,erase:true,focusedMinute}));
  console.log('FORGE Extension Host activation, commands, stop, no-token flush and erase passed');
}
module.exports={async run() {
  try { await run(); }
  catch(error) {
    if(process.env.FORGE_HOST_RESULT) require('node:fs').writeFileSync(process.env.FORGE_HOST_RESULT,JSON.stringify({status:'failed',kind:error.name,message:error.message}));
    throw error;
  } finally { await vscode.commands.executeCommand('forge.erase'); }
}};
