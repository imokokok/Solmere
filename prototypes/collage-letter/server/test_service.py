"""Transaction, persistence and real HTTP tests for two independent players."""
import concurrent.futures
import io
import json
from pathlib import Path
import tempfile
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from wsgiref.simple_server import make_server
from app import Service


class BottleTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.db=Path(self.temp.name)/'test.sqlite3'
        self.app=Service(self.db)
        self.a=self.register('甲')
        self.b=self.register('乙')
        self.sequence=0

    def tearDown(self):
        self.temp.cleanup()

    def call(self, path, token='', body=None, app=None):
        raw=json.dumps(body or {}).encode()
        env={'PATH_INFO':path.split('?')[0],'QUERY_STRING':path.partition('?')[2],
             'REQUEST_METHOD':'POST' if body is not None else 'GET',
             'CONTENT_LENGTH':str(len(raw)),'wsgi.input':io.BytesIO(raw),
             'HTTP_AUTHORIZATION':'Bearer '+token,'REMOTE_ADDR':'test'}
        status=[]
        result=b''.join((app or self.app)(env,lambda code,headers:status.append(int(code[:3]))))
        return status[0],json.loads(result)

    def register(self,name):
        code,data=self.call('/v1/players',body={'name':name})
        self.assertEqual(code,200)
        return data['token']

    def post(self,token,parent=None,key=None,caption='今天听见了海浪。'):
        self.sequence+=1
        return self.call('/v1/letters',token,{'title':'一封信','caption':caption,'parent_id':parent,
            'request_id':key or f'test-request-{self.sequence:06d}'})

    def test_full_unicode_letter_and_metadata_survive_roundtrip(self):
        text='  亲爱的你：\n'+('海边的风 é 👩‍👩‍👧‍👦 🇨🇳\n'*100)+'\n  '
        code, sent=self.call('/v1/letters',self.a,{'title':'长信', 'caption':text,
            'request_id':'unicode-long-letter-001', 'letter_data':{'letter_id':'original-id',
            'recipient':'远方的你','tone':'gentle','required_keywords':['海边']}})
        self.assertEqual(code,200)
        code, received=self.call('/v1/letters/'+str(sent['letter_id']),self.b)
        self.assertEqual(received['letter']['full_text'],text)
        self.assertEqual(received['letter']['letter_data']['recipient'],'远方的你')
        self.assertEqual(received['letter']['letter_data']['letter_id'],'original-id')
        self.assertTrue(received['letter']['letter_data']['sent'])

    def test_send_reply_send_and_inbox(self):
        code,original=self.post(self.a)
        self.assertEqual(code,200)
        self.assertTrue(original['player']['reply_required'])
        self.assertEqual(self.post(self.a)[0],409)
        code,reply=self.post(self.b,original['letter_id'])
        self.assertEqual(code,200)
        self.assertFalse(reply['player']['reply_required'])
        inbox=self.call('/v1/letters?view=inbox',self.a)[1]['letters']
        self.assertEqual(inbox[0]['parent'],original['letter_id'])
        self.assertEqual(self.post(self.a,reply['letter_id'])[0],200)
        self.assertEqual(self.post(self.a)[0],200)

    def test_own_or_duplicate_reply_cannot_pay_debt(self):
        _,original=self.post(self.a)
        self.assertEqual(self.post(self.a,original['letter_id'])[0],403)
        self.assertEqual(self.post(self.a,1)[0],200)
        self.assertEqual(self.post(self.a)[0],200)
        self.assertEqual(self.post(self.a,1)[0],409)
        self.assertTrue(self.call('/v1/me',self.a)[1]['player']['reply_required'])

    def test_retries_and_idempotency(self):
        _,first=self.post(self.a,key='unchanged-network-request')
        code,retry=self.post(self.a,key='unchanged-network-request')
        self.assertEqual(code,200)
        self.assertEqual(first['letter_id'],retry['letter_id'])
        self.assertTrue(retry['replayed'])
        self.assertEqual(self.post(self.a,key='unchanged-network-request',caption='different')[0],409)

    def test_server_restart_preserves_debt_and_letters(self):
        _,letter=self.post(self.a)
        replacement=Service(self.db)
        code,me=self.call('/v1/me',self.a,app=replacement)
        self.assertEqual(code,200)
        self.assertTrue(me['player']['reply_required'])
        code,data=self.call('/v1/letters/'+str(letter['letter_id']),self.b,app=replacement)
        self.assertEqual(code,200)
        self.assertFalse(data['letter']['is_seed'])

    def test_concurrent_send_is_atomic(self):
        def send(index):
            return self.call('/v1/letters',self.a,{'title':'并发信','caption':'same player',
                'request_id':f'concurrent-request-{index}'})[0]
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            codes=list(pool.map(send,range(6)))
        self.assertEqual(codes.count(200),1)
        self.assertEqual(codes.count(409),5)

    def test_auth_and_invalid_input(self):
        self.assertEqual(self.call('/v1/me','bad')[0],401)
        self.assertEqual(self.post(self.a,99999)[0],404)
        self.assertEqual(self.call('/v1/letters',self.a,{'title':'x','caption':'','request_id':'empty-content-check'})[0],400)
        self.assertEqual(self.call('/v1/letters',self.a,{'title':'x','art_png':'invalid','request_id':'invalid-png-check'})[0],400)
        self.assertFalse(self.call('/v1/me',self.a)[1]['player']['reply_required'])

    def test_pagination_reaches_old_letters(self):
        for i in range(15):
            self.post(self.register('寄信人'+str(i)))
        page=self.call('/v1/letters',self.a)[1]
        self.assertEqual(len(page['letters']),12)
        page2=self.call('/v1/letters?before='+str(page['next_before']),self.a)[1]
        self.assertTrue(any(item['is_seed'] for item in page2['letters']))
        self.assertFalse(set(x['id'] for x in page['letters']) & set(x['id'] for x in page2['letters']))

    def test_two_players_over_real_http(self):
        server=make_server('127.0.0.1',0,self.app)
        thread=threading.Thread(target=server.serve_forever,daemon=True)
        thread.start()
        try:
            base=f'http://127.0.0.1:{server.server_port}'
            def request(path,token,body=None):
                raw=None if body is None else json.dumps(body).encode()
                req=Request(base+path,data=raw,headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'})
                with urlopen(req,timeout=3) as response:
                    return json.load(response)
            letter=request('/v1/letters',self.a,{'title':'HTTP 测试','caption':'来自甲','request_id':'http-original-123'})
            request('/v1/letters',self.b,{'title':'回信','caption':'来自乙','request_id':'http-reply-123','parent_id':letter['letter_id']})
            inbox=request('/v1/letters?view=inbox',self.a)
            self.assertEqual(inbox['letters'][0]['caption'],'来自乙')
        finally:
            server.shutdown(); server.server_close(); thread.join()


if __name__=='__main__':
    unittest.main(verbosity=2)
