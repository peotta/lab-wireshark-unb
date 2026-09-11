#!/usr/bin/env python3
"""
Servidor HTTP minimo, so com biblioteca padrao do Python (sem dependencias),
usado no Modulo 3 do curso de Wireshark para simular um login em texto claro.

Uso:
    python3 login_server.py
    (escuta em 0.0.0.0:8080)

Credenciais validas (propositalmente fracas, e so para o exercicio):
    user: admin
    pass: SenhaSuperSecreta123
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs

FORM = b"""<form method="POST">
Usuario: <input name="user"><br>
Senha: <input name="pass" type="password"><br>
<button>Entrar</button>
</form>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(FORM)

    def do_POST(self):
        length = int(self.headers['Content-Length'])
        body = self.rfile.read(length).decode()
        data = parse_qs(body)
        user = data.get('user', [''])[0]
        pwd = data.get('pass', [''])[0]
        ok = (user == 'admin' and pwd == 'SenhaSuperSecreta123')
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"Login OK" if ok else b"Login invalido")

    def log_message(self, format, *args):
        # log simples no stdout, para o instrutor acompanhar tentativas ao vivo
        print(f"[login_server] {self.client_address[0]} - {format % args}")


if __name__ == '__main__':
    print("Servindo em http://0.0.0.0:8080 (Ctrl+C para parar)")
    HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
