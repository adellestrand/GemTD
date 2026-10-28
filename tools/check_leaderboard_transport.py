"""Exercise real native HTTPRequest against local compressed/plain scoreboards.

Web Fetch decompression must additionally be checked in an exported browser build.
No Supabase calls, player sessions or privileged keys are involved in this test.
"""
import gzip
import json
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from godot import ENGINE, ROOT, local_environment

BODY = json.dumps([{'display_name':'Åke transport test','completed_waves':i,'lives':0,
                    'verified':False,'created_at':'2026-10-28T00:00:00Z'} for i in range(20)],
                  ensure_ascii=False).encode('utf8')


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers.get('Content-Length','0')))
        compressed = self.path == '/gzip'
        body = gzip.compress(BODY) if compressed else BODY
        self.send_response(200)
        self.send_header('Content-Type','application/json; charset=utf-8')
        self.send_header('Content-Length',str(len(body)))
        if compressed: self.send_header('Content-Encoding','gzip')
        self.end_headers()
        self.wfile.write(body)

    def log_message(self,*args): pass


if __name__ == '__main__':
    with ThreadingHTTPServer(('127.0.0.1',0),Handler) as server:
        worker = threading.Thread(target=server.serve_forever,daemon=True)
        worker.start()
        try:
            result = subprocess.run([str(ENGINE),'--headless','--path','.',
                '--script','res://tests/check_leaderboard_transport.gd','--',
                f'--endpoint=http://127.0.0.1:{server.server_port}'],cwd=ROOT,env=local_environment(),
                capture_output=True,text=True,encoding='utf8',errors='replace',timeout=30)
            log = result.stdout+result.stderr
            print(log,end='')
            success = result.returncode == 0 and 'ERROR:' not in log and 'LEADERBOARD_TRANSPORT_CHECK_OK' in log
        finally:
            server.shutdown()
            worker.join(timeout=5)
    raise SystemExit(0 if success else 1)
