"""Isolated real-process persistence check; no changes to your normal task DB."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='planner-restart-') as temp:
    env = dict(os.environ, STUDENT_PLANNER_DB=temp+'/tasks.sqlite3')
    url = 'http://127.0.0.1:8020/api/planner/function/planner'
    def api(action, payload):
        req=urllib.request.Request(url,json.dumps({'action':action,'payload':payload}).encode(),{'Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=3) as r: return json.load(r)['data']['result']
    def start():
        log=open(temp+'/server.log','a')
        proc=subprocess.Popen(['jac','run','--port','8020','--no-dev','--host','127.0.0.1'],cwd=ROOT,env=env,stdout=log,stderr=log,start_new_session=True)
        for _ in range(180):
            if proc.poll() is not None: raise AssertionError(Path(temp+'/server.log').read_text())
            try:
                api('list',{})
                return proc,log
            except (OSError,ValueError): time.sleep(.5)
        stop(proc,log)
        raise AssertionError('Startup timeout: '+Path(temp+'/server.log').read_text())
    def stop(proc,log):
        os.killpg(proc.pid,signal.SIGTERM)
        try: proc.wait(timeout=20)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid,signal.SIGKILL);proc.wait()
        log.close()
    proc,log=start()
    try:
        made=api('add',{'title':'Restart persistence test','due_date':'2026-10-05','priority':'High','category':'Research','minutes':40})['task']
        api('edit',{'id':made['id'],'changes':{'notes':'survives a process restart'}})
        api('complete',{'id':made['id'],'completed':True})
    finally: stop(proc,log)
    proc,log=start()
    try:
        rows=api('list',{})['tasks']
        assert len(rows)==1 and rows[0]['id']==made['id'] and rows[0]['completed']
        assert rows[0]['notes']=='survives a process restart'
        api('delete',{'id':made['id']});assert not api('list',{})['tasks']
        print('PASS: real server restart preserves IDs, edits, notes and completion; delete persists.')
    finally: stop(proc,log)
