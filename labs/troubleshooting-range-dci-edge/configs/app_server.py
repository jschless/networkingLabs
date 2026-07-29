#!/usr/bin/env python3
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, required=True)
parser.add_argument("--body", required=True)
args = parser.parse_args()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        payload = (args.body + "\n").encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, _format, *_args):
        return


ThreadingHTTPServer(("0.0.0.0", args.port), Handler).serve_forever()
