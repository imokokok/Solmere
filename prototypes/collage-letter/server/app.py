"""Shared bottle-letter service. Standard-library WSGI app; SQLite is authoritative."""
import base64
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import secrets
import sqlite3
import struct
import threading
import time
from urllib.parse import parse_qs
import uuid

MAX_BODY = 1_100_000
MAX_PNG = 750_000


class APIError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


class Service:
    def __init__(self, database):
        self.database = str(database)
        Path(database).parent.mkdir(parents=True, exist_ok=True)
        self.signup_times = {}
        self.signup_lock = threading.Lock()
        with closing(self.connect()) as db:
            db.executescript("""
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS players (
                    id TEXT PRIMARY KEY, token_hash TEXT UNIQUE NOT NULL,
                    name TEXT NOT NULL, debt INTEGER NOT NULL DEFAULT 0,
                    created REAL NOT NULL
                );
                CREATE TABLE IF NOT EXISTS letters (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    author TEXT NOT NULL REFERENCES players(id),
                    parent INTEGER REFERENCES letters(id),
                    title TEXT NOT NULL, caption TEXT NOT NULL,
                    art_png TEXT NOT NULL DEFAULT '', created REAL NOT NULL,
                    request_id TEXT NOT NULL, payload_hash TEXT NOT NULL,
                    UNIQUE(author,request_id), UNIQUE(author,parent)
                );
                CREATE INDEX IF NOT EXISTS letters_parent ON letters(parent,id);
                CREATE INDEX IF NOT EXISTS letters_author ON letters(author,id);
            """)
            db.execute("INSERT OR IGNORE INTO players VALUES(?,?,?,?,?)",
                       ('station', 'unusable-station-token', '事务所 · 起航信', 0, 0))
            columns = {row[1] for row in db.execute('PRAGMA table_info(letters)')}
            if 'letter_data_json' not in columns:
                db.execute("ALTER TABLE letters ADD COLUMN letter_data_json TEXT NOT NULL DEFAULT '{}'")
            for i, (title, caption) in enumerate([
                ('给第一个捡到瓶子的人', '这是一封事务所准备的起航信。\n今天你注意到了什么不起眼的东西？\n可以给它留下一点位置。'),
                ('窗边的空位', '这是一封事务所准备的起航信。\n如果给今天的天气配一种颜色，\n你会从哪张纸上裁下来？'),
                ('一件还没做完的小事', '这是一封事务所准备的起航信。\n你手边有没有一件没做完的小事？\n也许另一个人，正好愿意听。'),
            ]):
                db.execute("INSERT OR IGNORE INTO letters(author,title,caption,created,request_id,payload_hash) VALUES(?,?,?,?,?,?)",
                           ('station', title, caption, 0, f'seed-{i}', 'seed'))

    def connect(self):
        db = sqlite3.connect(self.database, timeout=15, isolation_level=None)
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA foreign_keys=ON')
        return db

    def __call__(self, env, start_response):
        try:
            result = self.route(env)
            status, payload = 200, result
        except APIError as exc:
            status, payload = exc.status, {'error': exc.message}
        except (ValueError, TypeError, KeyError, UnicodeError):
            status, payload = 400, {'error': '请求格式有误。'}
        except sqlite3.Error:
            status, payload = 503, {'error': '海岸邮局暂时繁忙，请稍后重试。'}
        body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
        names = {200:'OK',400:'Bad Request',401:'Unauthorized',403:'Forbidden',404:'Not Found',409:'Conflict',413:'Payload Too Large',429:'Too Many Requests',503:'Service Unavailable'}
        start_response(f'{status} {names.get(status,"Error")}', [
            ('Content-Type','application/json; charset=utf-8'),
            ('Content-Length',str(len(body))),('Cache-Control','no-store'),
            ('X-Content-Type-Options','nosniff')])
        return [body]

    def body(self, env):
        length = int(env.get('CONTENT_LENGTH') or 0)
        if not 0 < length <= MAX_BODY:
            raise APIError(413, '信件太大或内容为空。')
        value = json.loads(env['wsgi.input'].read(length))
        if not isinstance(value, dict):
            raise APIError(400, '请求必须为 JSON 对象。')
        return value

    def player(self, db, env):
        header = env.get('HTTP_AUTHORIZATION','')
        if not header.startswith('Bearer '):
            raise APIError(401, '请先连接邮局，建立你的寄信身份。')
        token_hash = hashlib.sha256(header[7:].encode()).hexdigest()
        row = db.execute('SELECT * FROM players WHERE token_hash=?',(token_hash,)).fetchone()
        if row is None:
            raise APIError(401, '这个寄信身份已失效，请重新连接。')
        return row

    @staticmethod
    def public_player(row):
        return {'id':row['id'],'name':row['name'],'reply_required':bool(row['debt'])}

    @staticmethod
    def text(value, limit, required=False):
        if not isinstance(value, str) or len(value.strip()) > limit:
            raise APIError(400, f'文字超出 {limit} 字限制。')
        value = value.strip()
        if required and not value:
            raise APIError(400, '请给信件写一个标题。')
        return value

    def route(self, env):
        path, method = env.get('PATH_INFO',''), env.get('REQUEST_METHOD','GET')
        with closing(self.connect()) as db:
            if path=='/health' and method=='GET':
                return {'service':'collage-letter','version':2}
            if path=='/v1/players' and method=='POST':
                body = self.body(env)
                name = self.text(body.get('name','海边来客'), 24, True)
                ip = env.get('REMOTE_ADDR','local')
                with self.signup_lock:
                    recent = [t for t in self.signup_times.get(ip,[]) if time.time()-t<3600]
                    if len(recent)>=30:
                        raise APIError(429, '建立身份过于频繁，请稍后再试。')
                    self.signup_times[ip] = recent+[time.time()]
                token, player_id = secrets.token_urlsafe(32), uuid.uuid4().hex
                db.execute('INSERT INTO players VALUES(?,?,?,?,?)',
                           (player_id,hashlib.sha256(token.encode()).hexdigest(),name,0,time.time()))
                return {'token':token,'player':{'id':player_id,'name':name,'reply_required':False}}
            player = self.player(db, env)
            if path=='/v1/me' and method=='GET':
                return {'player':self.public_player(player)}
            if path=='/v1/letters' and method=='POST':
                return self.publish(db, player, self.body(env))
            query = parse_qs(env.get('QUERY_STRING',''))
            if path=='/v1/letters' and method=='GET':
                view = query.get('view',['ocean'])[0]
                before = int(query.get('before',[str(2**62)])[0])
                conditions, params = ['l.id < ?'], [before]
                if view=='mine':
                    conditions.append('l.author=?'); params.append(player['id'])
                elif view=='inbox':
                    conditions.append('l.parent IN (SELECT id FROM letters WHERE author=?)'); params.append(player['id'])
                elif view=='ocean':
                    conditions.append('l.author<>?'); params.append(player['id'])
                else:
                    raise APIError(400,'未知的信箱。')
                rows = db.execute(self.select(False)+' WHERE '+' AND '.join(conditions)+' ORDER BY l.id DESC LIMIT 13',params).fetchall()
                letters = [self.letter(row,player) for row in rows[:12]]
                return {'letters':letters,'next_before':letters[-1]['id'] if len(rows)>12 else None,'player':self.public_player(player)}
            if path.startswith('/v1/letters/') and method=='GET':
                letter_id = int(path.rsplit('/',1)[1])
                row = db.execute(self.select(True)+' WHERE l.id=?',(letter_id,)).fetchone()
                if not row:
                    raise APIError(404,'没有找到这封信。')
                replies = db.execute(self.select(False)+' WHERE l.parent=? ORDER BY l.id DESC LIMIT 100',(letter_id,)).fetchall()
                item = self.letter(row,player)
                item['already_replied'] = bool(db.execute('SELECT 1 FROM letters WHERE author=? AND parent=?',(player['id'],letter_id)).fetchone())
                return {'letter':item,'replies':[self.letter(r,player) for r in replies],'player':self.public_player(player)}
            raise APIError(404,'没有这个邮局接口。')

    @staticmethod
    def select(art):
        return 'SELECT l.id,l.author,l.parent,l.title,l.caption,l.created,l.letter_data_json,p.name'+(',l.art_png' if art else '')+', (SELECT COUNT(*) FROM letters r WHERE r.parent=l.id) AS reply_count FROM letters l JOIN players p ON p.id=l.author'

    @staticmethod
    def letter(row, player):
        result = dict(row)
        result['is_own'] = row['author']==player['id']
        result['is_seed'] = row['author']=='station'
        data = json.loads(result.pop('letter_data_json', '{}'))
        data.update(full_text=row['caption'], author_id=row['author'], reply_to=row['parent'],
                    sender=row['name'], completed=True, sealed=True, sent=True)
        data.setdefault('letter_id', str(row['id']))
        data.setdefault('created_time', row['created'])
        data.setdefault('letter_type', 'reply' if row['parent'] is not None else 'bottle')
        data.setdefault('reply_chain_id', str(row['parent'] or row['id']))
        result['letter_data'] = data
        result['full_text'] = row['caption']
        return result

    def publish(self, db, player, body):
        request_id = str(body.get('request_id',''))
        if not 12 <= len(request_id) <= 80:
            raise APIError(400,'缺少寄信流水号。')
        parent = body.get('parent_id')
        if parent is not None and (isinstance(parent,bool) or not isinstance(parent,int)):
            raise APIError(400,'回信目标有误。')
        title = self.text(body.get('title',''),40,True)
        caption = body.get('caption','')
        if not isinstance(caption, str) or len(caption)>12000:
            raise APIError(400, '信件正文最多 12000 字，请保留本地草稿后分信寄出。')
        metadata = body.get('letter_data', {})
        if not isinstance(metadata,dict):
            raise APIError(400, '信件资料格式有误。')
        metadata = {key:value for key,value in metadata.items() if key in {
            'letter_id','recipient','created_time','letter_type','reply_chain_id','tone',
            'required_keywords','forbidden_keywords'}}
        if len(json.dumps(metadata,ensure_ascii=False))>16000:
            raise APIError(400, '信件资料过长。')
        metadata_json=json.dumps(metadata,ensure_ascii=False,sort_keys=True)
        png = body.get('art_png','')
        if not isinstance(png,str) or len(png)>MAX_PNG*4//3+8:
            raise APIError(413,'作品图片太大。')
        if png:
            try:
                raw = base64.b64decode(png, validate=True)
                width,height = struct.unpack('>II',raw[16:24])
                if raw[:16]!=b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR' or not (1<=width<=1536 and 1<=height<=1536) or len(raw)>MAX_PNG:
                    raise ValueError()
            except (ValueError, struct.error):
                raise APIError(400,'作品需要有效且不超过 1536 像素的 PNG。')
        if not png and not caption.strip():
            raise APIError(400,'空信不能投进海里，请留下作品或文字。')
        payload_hash = hashlib.sha256(json.dumps([parent,title,caption,png]+([metadata_json] if metadata else []),ensure_ascii=False).encode()).hexdigest()
        db.execute('BEGIN IMMEDIATE')
        try:
            existing = db.execute('SELECT id,payload_hash FROM letters WHERE author=? AND request_id=?',(player['id'],request_id)).fetchone()
            if existing:
                if existing['payload_hash']!=payload_hash:
                    raise APIError(409,'这次寄信的内容已改变，请使用新的流水号。')
                current = db.execute('SELECT * FROM players WHERE id=?',(player['id'],)).fetchone()
                db.commit()
                return {'letter_id':existing['id'],'player':self.public_player(current),'replayed':True}
            current = db.execute('SELECT * FROM players WHERE id=?',(player['id'],)).fetchone()
            if parent is None and current['debt']:
                raise APIError(409,'你已发出一封信。请先回复另一位寄信人，再投出新的漂流瓶。')
            if parent is not None:
                target = db.execute('SELECT author FROM letters WHERE id=?',(parent,)).fetchone()
                if not target:
                    raise APIError(404,'原信不存在。')
                if target['author']==player['id']:
                    raise APIError(403,'请回复其他寄信人的信，不能用自己的信抵扣回信。')
                if db.execute('SELECT 1 FROM letters WHERE author=? AND parent=?',(player['id'],parent)).fetchone():
                    raise APIError(409,'你已经回复过这封信，请选另一封。')
            cursor = db.execute('INSERT INTO letters(author,parent,title,caption,art_png,created,request_id,payload_hash,letter_data_json) VALUES(?,?,?,?,?,?,?,?,?)',
                                (player['id'],parent,title,caption,png,time.time(),request_id,payload_hash,metadata_json))
            db.execute('UPDATE players SET debt=? WHERE id=?',(int(parent is None),player['id']))
            current = db.execute('SELECT * FROM players WHERE id=?',(player['id'],)).fetchone()
            db.commit()
            return {'letter_id':cursor.lastrowid,'player':self.public_player(current),'replayed':False}
        except Exception:
            db.rollback()
            raise


_service = None
_service_lock = threading.Lock()


def application(environ, start_response):
    global _service
    with _service_lock:
        if _service is None:
            default = Path(os.environ.get('LOCALAPPDATA', str(Path.home()))) / 'CollageLetterServer' / 'letters.sqlite3'
            _service = Service(os.environ.get('COLLAGE_DB', default))
    return _service(environ,start_response)


def create_http_server(app=application, host='127.0.0.1', port=8787):
    """Pinned, unmodified Waitress serves both desktop and deployable builds."""
    import sys
    vendor = str(Path(__file__).resolve().parent / 'vendor')
    if vendor not in sys.path:
        sys.path.insert(0, vendor)
    from waitress import create_server
    return create_server(app, host=host, port=port, threads=8,
                         connection_limit=128, channel_timeout=30,
                         max_request_body_size=MAX_BODY,
                         max_request_header_size=16384,
                         expose_tracebacks=False)


if __name__=='__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--host',default='127.0.0.1')
    parser.add_argument('--port',type=int,default=8787)
    args = parser.parse_args()
    server = create_http_server(host=args.host, port=args.port)
    try:
        print(f'Collage Letter service: http://{args.host}:{args.port}',flush=True)
        server.run()
    finally:
        server.close()
        server.task_dispatcher.shutdown()
