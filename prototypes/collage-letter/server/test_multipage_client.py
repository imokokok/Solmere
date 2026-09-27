"""Real Godot multi-page delivery after a lost response; isolated DB and identity."""
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
from contextlib import closing
from app import Service, create_http_server


def isolated_project(source, destination):
    """Reuse imported assets but never load the player's project settings/save."""
    destination.mkdir()
    config = (source/'project.godot').read_text(encoding='utf-8')
    config = re.sub(r'^config/name=.*$', 'config/name="Collage Letter Multipage Regression"', config, flags=re.M)
    config = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir)=.*\n?', '', config, flags=re.M)
    (destination/'project.godot').write_text(config, encoding='utf-8')
    for name in ['assets', 'scripts', 'tests', '.godot']:
        original = source/name
        if not original.exists():
            continue
        try:
            (destination/name).symlink_to(original, target_is_directory=True)
        except OSError:
            # Windows machines without symlink privileges can still run the test.
            shutil.copytree(original, destination/name)
    for name in ['Main.tscn', 'network.cfg']:
        shutil.copy2(source/name, destination/name)
    return destination


def run():
    with tempfile.TemporaryDirectory() as directory:
        service = Service(Path(directory)/'pages.sqlite3')
        calls = {}
        stopping = threading.Event()

        def faulty(env, respond):
            raw = env['wsgi.input'].read(int(env.get('CONTENT_LENGTH') or 0))
            env['wsgi.input'] = io.BytesIO(raw)
            data = json.loads(raw) if raw else {}
            headers = []
            body = list(service(env, lambda status, values: headers.append((status, values))))
            if env['PATH_INFO']=='/v1/letters' and env['REQUEST_METHOD']=='POST':
                key = data['request_id']
                calls[key] = calls.get(key, 0)+1
                if calls[key]==1 and headers[0][0].startswith('200'):
                    respond('503 Service Unavailable', [('Content-Type','application/json')])
                    return [b'{"error":"injected lost response after multi-page commit"}']
            respond(*headers[0])
            return body

        server = create_http_server(faulty, port=0)

        def serve():
            try:
                server.run()
            except OSError:
                if not stopping.is_set():
                    raise

        thread = threading.Thread(target=serve, daemon=True)
        thread.start()
        try:
            source = Path(os.environ.get('COLLAGE_PROJECT', Path(__file__).resolve().parent.parent)).resolve()
            root = isolated_project(source, Path(directory)/'project')
            env = dict(os.environ, COLLAGE_TEST_URL=f'http://127.0.0.1:{server.effective_port}')
            if not (root/'.godot').exists():
                subprocess.run([os.environ['GODOT_BIN'], '--headless', '--path', str(root),
                                '--editor', '--import', '--quit'], env=env, check=True, timeout=120)
            command = [os.environ['GODOT_BIN'], '--path', str(root), '--script',
                       'res://tests/multipage_delivery_test.gd', '--', '--fresh',
                       '--lang=zh', '--profile=multipage-regression']
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=90)
            print(result.stdout)
            print(result.stderr)
            assert result.returncode==0 and 'MULTIPAGE_DELIVERY_TEST: PASS' in result.stdout
            assert 'SCRIPT ERROR' not in result.stderr and 'ERROR:' not in result.stderr
            assert list(calls.values())==[2], calls
            with closing(service.connect()) as db:
                rows = db.execute("SELECT art_pages_json FROM letters WHERE author<>'station'").fetchall()
                assert len(rows)==1 and len(json.loads(rows[0][0]))==3
            print('MULTIPAGE_HTTP_PASS: one committed letter, all three pages, exact retry, readback and localization')
        finally:
            stopping.set()
            server.close()
            server.task_dispatcher.shutdown()
            thread.join(timeout=3)


if __name__=='__main__':
    run()
