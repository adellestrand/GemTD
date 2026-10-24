"""Local-only web export server. No public hosting, TLS or external dependencies."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8060)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1] / 'builds/web'
    if not (root / 'index.html').exists():
        raise SystemExit('Export the Web preset first.')
    print(f'GemTD: http://127.0.0.1:{args.port} — Ctrl+C to stop.', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), partial(Handler, directory=str(root))).serve_forever()
