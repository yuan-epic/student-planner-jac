"""Run against an already-running web server and compiled mobile web preview.
The mobile preview verifies the real Jac screen/HTTP client, not native iOS.
Creates only synthetic tasks; deletes its own IDs in finally.
"""
import json
import os
import subprocess
import uuid
import urllib.request
from playwright.sync_api import sync_playwright, expect

SERVER = os.environ.get('STUDENT_PLANNER_URL', 'http://127.0.0.1:8000')
MOBILE = os.environ.get('STUDENT_PLANNER_MOBILE_PREVIEW', 'http://127.0.0.1:8010')
ids = []

def api(action, payload):
    req = urllib.request.Request(SERVER + '/api/planner/function/planner',
        json.dumps({'action': action, 'payload': payload}).encode(), {'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=15) as r:
        envelope = json.load(r)
    return envelope['data']['result']

def cli(*args, expected=0):
    p = subprocess.run(['jac', 'run', 'cli', '--', '--server', SERVER, *args], text=True, capture_output=True, timeout=30)
    assert p.returncode == expected, (p.stdout, p.stderr)
    return json.loads(p.stdout) if expected == 0 else p.stderr

try:
    today = api('list', {})['today']
    name = 'E2E-' + uuid.uuid4().hex[:8]
    made = cli('add', name, '--due', today, '--category', 'Research', '--minutes', '25')
    task_id = made['task']['id']; ids.append(task_id)
    with sync_playwright() as p:
        b = p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = b.new_page(viewport={'width':1440,'height':1000})
        errors = []; page.on('pageerror', lambda e: errors.append(str(e)))
        page.goto(SERVER)
        row = page.locator('article').filter(has_text=task_id)
        expect(row).to_be_visible()
        row.get_by_role('button', name='Edit', exact=True).click()
        dialog = page.get_by_role('dialog')
        dialog.get_by_label('Title', exact=True).fill(name + ' edited')
        dialog.get_by_label('Notes (optional)').fill('Synthetic cross-client test')
        dialog.get_by_role('button', name='Save task').click()
        expect(dialog).not_to_be_visible()
        assert next(t for t in cli('list')['tasks'] if t['id']==task_id)['title'] == name + ' edited'
        page.get_by_role('button', name='Build my plan').click()
        expect(page.get_by_text('120 minutes planned', exact=False)).to_be_visible()
        mobile = b.new_page(viewport={'width':390,'height':844})
        mobile.on('pageerror', lambda e: errors.append(str(e)))
        mobile.goto(MOBILE)
        mobile.get_by_label('Backend URL').fill(SERVER)
        mobile.get_by_text('Connect / Refresh', exact=True).click()
        expect(mobile.get_by_text(name + ' edited', exact=True)).to_be_visible()
        # Find the card containing the shared ID, then use its completion action.
        mobile.get_by_text(name + ' edited', exact=True).locator('..').get_by_text('Complete task', exact=True).click()
        expect(mobile.get_by_text('✓ ' + name + ' edited', exact=True)).to_be_visible()
        assert next(t for t in cli('list')['tasks'] if t['id']==task_id)['completed'] is True
        page.get_by_role('button', name='Refresh', exact=True).click()
        expect(row.get_by_role('button', name='Restore ' + name + ' edited', exact=True)).to_be_visible()
        cli('restore', task_id)
        mobile.get_by_text('Connect / Refresh', exact=True).click()
        expect(mobile.get_by_text(name + ' edited', exact=True)).to_be_visible()
        mobile.get_by_label('Task title', exact=True).fill(name + ' mobile')
        mobile.get_by_label('Due date', exact=True).fill(today)
        mobile.get_by_label('Estimated minutes').fill('15')
        mobile.get_by_text('Add task', exact=True).click()
        expect(mobile.get_by_text(name + ' mobile', exact=True)).to_be_visible()
        mobile_id = next(t['id'] for t in api('list', {})['tasks'] if t['title']==name + ' mobile'); ids.append(mobile_id)
        page.get_by_role('button', name='Refresh', exact=True).click()
        expect(page.locator('article').filter(has_text=name + ' mobile')).to_be_visible()
        # Delete confirmation: cancel preserves task, accept removes it.
        page.once('dialog', lambda d:d.dismiss()); row.get_by_role('button',name='Delete',exact=True).click()
        expect(row).to_be_visible()
        page.once('dialog', lambda d:d.accept()); row.get_by_role('button',name='Delete',exact=True).click()
        expect(row).not_to_be_visible()
        assert task_id not in [t['id'] for t in cli('list')['tasks']]
        # Web form create + mark complete + restore.
        page.get_by_role('button',name='+ New task').click()
        dialog.get_by_label('Title',exact=True).fill(name + ' web')
        dialog.get_by_role('button',name='Save task').click()
        newrow = page.locator('article').filter(has_text=name + ' web'); expect(newrow).to_be_visible()
        web_id = next(t['id'] for t in api('list', {})['tasks'] if t['title']==name + ' web'); ids.append(web_id)
        newrow.get_by_role('button', name='Complete ' + name + ' web', exact=True).click()
        newrow.get_by_role('button', name='Restore ' + name + ' web', exact=True).click()
        expect(newrow.get_by_role('button',name='Complete ' + name + ' web',exact=True)).to_be_visible()
        # In-app errors, rather than a white screen.
        page.route('**/function/planner', lambda route:route.abort())
        page.get_by_role('button',name='Refresh',exact=True).click()
        expect(page.get_by_role('alert')).to_contain_text('Cannot reach')
        page.unroute('**/function/planner')
        mobile.get_by_label('Backend URL').fill('http://127.0.0.1:1')
        mobile.get_by_text('Connect / Refresh',exact=True).click()
        expect(mobile.get_by_role('alert')).to_contain_text('Could not load')
        assert not errors, errors
        b.close()
    assert 'minutes' in cli('add','Invalid','--due',today,'--minutes','-1',expected=2)
    bad = subprocess.run(['jac','run','cli','--','--server','http://127.0.0.1:1','list'], capture_output=True,text=True,timeout=30)
    assert bad.returncode == 3 and 'Cannot reach' in bad.stderr
    print('PASS: CLI → Web → Mobile screen → CLI/Web; CRUD; restore; confirmation; errors; no JS runtime errors.')
finally:
    for task_id in ids:
        api('delete', {'id':task_id})
