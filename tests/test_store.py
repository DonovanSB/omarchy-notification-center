import json, os, subprocess, tempfile, time, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'bin/notification-center'
class StoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='notification-center-test-')
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        (self.source / 'history').mkdir(parents=True)
        self.store = self.root / 'archive'
        self.env = dict(os.environ, NC_STORE=str(self.store), NC_SRC_DIR=str(self.source), NC_MAX_ITEMS='1000')
        self.now = int(time.time()*1000)
    def tearDown(self): self.temp.cleanup()
    def run_store(self, *args):
        result = subprocess.run([str(SCRIPT),*map(str,args)],env=self.env,capture_output=True,text=True,timeout=15)
        self.assertEqual(result.returncode,0,result.stderr+result.stdout)
        return json.loads(result.stdout)
    def source_entry(self, id=1, stamp=None, **fields):
        stamp = self.now if stamp is None else stamp
        entry=dict(app='Test',summary='Hello',body='Body',timestamp=stamp,urgency=1,**fields)
        path=self.source/f'{stamp}-{id}.json'; path.write_text(json.dumps(entry)); return path
    def test_sync_dedupe_update_and_source_preserved(self):
        path=self.source_entry(); self.run_store('sync'); self.run_store('sync')
        self.assertEqual(len(self.run_store('list')),1)
        entry=json.loads(path.read_text()); entry['summary']='Updated'; path.write_text(json.dumps(entry))
        self.run_store('sync'); rows=self.run_store('list')
        self.assertEqual(len(rows),1); self.assertEqual(rows[0]['summary'],'Updated')
        self.run_store('remove',rows[0]['key']); self.run_store('sync')
        self.assertEqual(self.run_store('list'),[]); self.assertTrue(path.exists())
    def test_batch_remove_persists(self):
        paths=[self.source_entry(i) for i in range(3)]; self.run_store('sync')
        rows=self.run_store('list'); self.run_store('remove',*[r['key'] for r in rows[:2]])
        self.run_store('sync'); self.assertEqual(len(self.run_store('list')),1)
        self.assertTrue(all(p.exists() for p in paths))
    def test_clear_cutoff_keeps_later_arrivals_and_sources(self):
        before=self.source_entry(stamp=self.now-10); after=self.source_entry(2, self.now+10)
        self.run_store('sync'); self.run_store('clear',self.now); self.run_store('sync')
        self.assertEqual([r['key'] for r in self.run_store('list')],[after.stem])
        self.assertTrue(before.exists()); self.assertTrue(after.exists())
    def test_retention_sorts_by_time_not_ingest_order(self):
        self.env['NC_MAX_ITEMS']='2'
        paths=[self.source_entry(i,self.now-i*1000) for i in range(4)]
        old=self.source_entry(99,self.now-40*86400000)
        self.run_store('sync'); rows=self.run_store('list')
        self.assertEqual([r['key'] for r in rows],[paths[0].stem,paths[1].stem])
        self.assertTrue(old.exists()); self.assertTrue(all(p.exists() for p in paths))
    def test_corrupt_line_does_not_erase_valid_rows(self):
        self.source_entry(); self.run_store('sync')
        with (self.store/'archive.jsonl').open('a') as f:
            f.write('broken json\n'); f.write(json.dumps(dict(key='new',timestamp=self.now+1,app='Test'))+'\n')
        self.assertEqual(len(self.run_store('list')),2)
    def test_page_limit_valid_json_for_large_archive(self):
        self.run_store('sync')
        (self.store/'archive.jsonl').write_text(''.join(json.dumps(dict(key=str(i),timestamp=self.now-i,body='x'*500))+'\n' for i in range(1000)))
        rows=self.run_store('list',50); self.assertEqual(len(rows),50); self.assertEqual(rows[0]['key'],'0')
    def test_no_stored_commands_or_nonimage_copy(self):
        secret=self.root/'fake.png'; secret.write_text('not an image')
        self.source_entry(appIcon=str(secret),execArgv=['touch','/tmp/SHOULD-NOT-EXIST',str(secret)])
        self.run_store('sync'); row=self.run_store('list')[0]
        self.assertNotIn('execArgv',row); self.assertNotIn('exec',row)
        self.assertEqual(row['appIcon'],''); self.assertEqual(row['preview'],'')
        self.assertEqual(self.store.stat().st_mode & 0o777,0o700)
        self.assertEqual((self.store/'archive.jsonl').stat().st_mode & 0o777,0o600)
    def test_watch_receives_notification(self):
        proc=subprocess.Popen([str(SCRIPT),'watch'],env=self.env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            time.sleep(.2); self.source_entry()
            deadline=time.monotonic()+5
            while time.monotonic()<deadline:
                if self.run_store('list'): break
                time.sleep(.1)
            self.assertEqual(len(self.run_store('list')),1)
        finally:
            proc.terminate(); proc.communicate(timeout=5)
if __name__=='__main__': unittest.main()
