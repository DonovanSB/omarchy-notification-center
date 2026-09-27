#!/usr/bin/env python3
"""Install a local copy, migrate the existing archive, and replace the two bells."""
import json, os, shutil, subprocess, time
from pathlib import Path

source = Path(__file__).resolve().parent
home = Path.home()
config = home / '.config/omarchy'
target = config / 'plugins/donovan.notification-center'
state_home = Path(os.environ.get('XDG_STATE_HOME', home / '.local/state'))
state = state_home / 'donovan-notification-center'
legacy = state_home / 'omarchy-notification-center'
stamp = time.strftime('%Y%m%d-%H%M%S')
subprocess.run(['omarchy','plugin','validate',str(source)],check=True)
backup = config / f'shell.json.before-donovan-notifications-{stamp}'
shutil.copy2(config/'shell.json',backup)
if target.exists():
    shutil.copytree(target,state_home/f'donovan-notification-plugin-backup-{stamp}')
shutil.copytree(source,target,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.git','__pycache__','tests'))
# Preserve dismissed/seen state and all images without altering the original archive.
if not state.exists() and legacy.exists():
    shutil.copytree(legacy,state,ignore=shutil.ignore_patterns('lock','*.tmp'))
    archive=state/'archive.jsonl'
    if archive.exists():
        cleaned=[]
        for line in archive.read_text().splitlines():
            try: row=json.loads(line)
            except ValueError: continue
            if not isinstance(row,dict): continue
            row.pop('exec',None); row.pop('execArgv',None)
            for name in ['appIcon','image','preview']:
                if isinstance(row.get(name),str): row[name]=row[name].replace(str(legacy/'images'),str(state/'images'))
            cleaned.append(json.dumps(row,separators=(',',':'),ensure_ascii=False))
        archive.write_text('\n'.join(cleaned)+'\n')
    for path in [state,*state.rglob('*')]:
        path.chmod(0o700 if path.is_dir() else 0o600)
# Replace at the first old bell's position, preserving the rest of the layout.
data=json.loads((config/'shell.json').read_text())
old={'jankeesvw.notification-center','shavanced.notification-center'}
new='donovan.notification-center'
placed=any(row.get('id')==new for rows in data['bar']['layout'].values() for row in rows)
for section,rows in data['bar']['layout'].items():
    updated=[]
    for row in rows:
        if row.get('id') in old:
            if not placed: updated.append({'id':new}); placed=True
        else: updated.append(row)
    data['bar']['layout'][section]=updated
if not placed: data['bar']['layout']['right'].append({'id':new})
data['plugins']=[row for row in data.get('plugins',[]) if (row if isinstance(row,str) else row.get('id')) not in old]
temporary=config/'shell.json.donovan-tmp'
temporary.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n')
temporary.replace(config/'shell.json')
subprocess.run(['omarchy-shell','shell','rescanPlugins'],check=True)
print(f'Installed: {target}\nConfiguration backup: {backup}')
