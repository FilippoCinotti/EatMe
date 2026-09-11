"""Dependency-free development HTTP adapter; only binds loopback by default.

This exercises the same transport/domain as FastAPI when packages cannot be
installed. It is never a production HTTP server.
"""
import argparse
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from uuid import uuid4

from .errors import DomainError
from .transport import configured_router


def create_server(router,host="127.0.0.1",port=8000):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args):
            pass  # Do not log tokens, profiles, request bodies or query strings.

        def handle_request(self):
            try:
                size = int(self.headers.get("Content-Length","0"))
                if not 0<=size<=262144:
                    raise DomainError("payload_too_large",413)
                raw = self.rfile.read(size)
                body = json.loads(raw) if raw else {}
                result = router.dispatch(self.command,self.path,body,self.headers.get("Authorization",""),
                                         self.headers.get("Idempotency-Key",""),self.client_address[0])
                status = 200
            except DomainError as error:
                status,result = error.status,error.payload()
            except (ValueError,UnicodeError):
                status,result = 422,{"error":{"code":"invalid_json"}}
            except Exception:
                status,result = 500,{"error":{"code":"internal_error"}}
            payload = json.dumps(result,ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header("Content-Type","application/json; charset=utf-8")
            self.send_header("Content-Length",str(len(payload)))
            self.send_header("Cache-Control","no-store")
            self.send_header("X-Content-Type-Options","nosniff")
            self.send_header("X-Request-ID",str(uuid4()))
            self.end_headers()
            self.wfile.write(payload)

        do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = handle_request

    return ThreadingHTTPServer((host,port),Handler)


def main():
    if os.getenv("EATME_ENV","development")!="development":
        raise RuntimeError("Local HTTP server is development-only")
    parser = argparse.ArgumentParser()
    parser.add_argument("--host",default="127.0.0.1")
    parser.add_argument("--port",type=int,default=8000)
    args = parser.parse_args()
    server = create_server(configured_router(),args.host,args.port)
    print(f"EatMe DEVELOPMENT API: http://{args.host}:{args.port}/api/v1/health",flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()


if __name__=="__main__":
    main()
