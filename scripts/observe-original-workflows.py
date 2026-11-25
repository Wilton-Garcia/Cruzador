#!/usr/bin/env python3
"""Observe selected original CLI workflows in a new owned bottle; retain output."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time
import uuid

ROOT=Path(__file__).resolve().parent.parent
APP=Path('/Applications/CrossOver.app/Contents/SharedSupport/CrossOver')

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

if __name__=='__main__':
    workspace=ROOT/'.local/original-scenarios'/str(uuid.uuid4());bottles=workspace/'Bottles';bottles.mkdir(parents=True)
    name=str(uuid.uuid4());prefix=bottles/name
    selected={'CX_BOTTLE_PATH':str(bottles),'CX_BOTTLE':name,'WINEPREFIX':str(prefix)}
    environment={k:v for k,v in os.environ.items() if not k.startswith(('CX_','WINE'))};environment.update(selected)
    output=ROOT/'evidence/runtime';output.mkdir(exist_ok=True)
    runs=[]
    def run(id,tool,args,expected):
        log=workspace/(id+'.log');exe=APP/'bin'/tool
        with log.open('wb') as handle:
            process=subprocess.Popen([str(exe)]+args,cwd=workspace,env=environment,stdout=handle,stderr=subprocess.STDOUT,start_new_session=True)
            timed_out=False
            try:code=process.wait(timeout=90)
            except subprocess.TimeoutExpired:
                timed_out=True;os.killpg(process.pid,signal.SIGTERM)
                try:code=process.wait(timeout=5)
                except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);code=process.wait()
        text=log.read_text(errors='replace')
        result={'id':id,'executable':str(exe),'executable_sha256':digest(exe),'arguments':args,'selected_environment':selected,
                'working_directory':str(workspace),'exit_code':code,'timed_out':timed_out,'expected':expected,
                'log_path':str(log),'log_sha256':digest(log),'output':text}
        runs.append(result)
        assert not timed_out,f'{id} timed out; retained prefix must be inspected'
        if expected=='success':assert code==0,(id,code,text)
        elif expected=='failure':assert code!=0,(id,code,text)
        else:assert code==expected,(id,code,text)
        print(id,code,flush=True)
        return text
    common=['--bottle',name,'--scope','private']
    report={'method':'supervised direct subprocesses; no PTY, process-family sampling or terminal frames','workspace':str(workspace),'prefix':str(prefix),'runs':runs,'completed':False}
    try:
        run('create','cxbottle',common+['--create','--template','win10_64'],'success')
        assert (prefix/'system.reg').is_file() and (prefix/'drive_c').is_dir()
        run('duplicate-create-rejected','cxbottle',common+['--create','--template','win10_64'],'failure')
        run('status-after-create-conflict','cxbottle',common+['--status'],'success')
        wine=common+['--no-gui','--wait','--']
        text=run('windows-command','wine',wine+['cmd.exe','/c','echo','CRUZADOR_ORIGINAL_OK'],'success')
        assert 'CRUZADOR_ORIGINAL_OK' in text
        run('windows-nonzero-exit','wine',wine+['cmd.exe','/c','exit','7'],7)
        run('missing-program','wine',wine+['C:\\cruzador-no-such-program.exe'],'failure')
        text=run('command-after-errors','wine',wine+['cmd.exe','/c','echo','CRUZADOR_RECOVERED_OK'],'success')
        assert 'CRUZADOR_RECOVERED_OK' in text
        report['completed']=True
    finally:
        try:
            run('wait-owned-server','wine',common+['--no-gui','--wait-all'],'success')
            report['server_wait']='completed'
        except Exception as error:
            report['server_wait']='unresolved';report['cleanup_error']=str(error);report['completed']=False
        report['bottle_metadata']={'path':str(prefix/'cxbottle.conf'),'sha256':digest(prefix/'cxbottle.conf') if (prefix/'cxbottle.conf').is_file() else None}
        report['limitations']=['No process-family census or terminal rendering was collected.','Waiting for the prefix server does not prove that every detached host helper exited.','The retained prefix is test data and was not deleted.','Graphical installer cancellation is referenced separately in ui-observations.json.','No general Windows compatibility or independent runtime was established.']
        (output/'original-workflows.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    assert report['completed'],'Scenario or cleanup failed; inspect retained evidence'
