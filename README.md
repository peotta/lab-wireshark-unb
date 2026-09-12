# lab-wireshark-unb

Laboratório prático de 2h - captura e análise de pacotes com Wireshark, em Kali Linux.
Cada aluno roda tudo localmente na própria VM: tráfego real contra `unb.br` (DNS/TCP/TLS)
e um serviço local simulado (login em texto claro + demonstração de DoS/spoofing contra
a própria máquina).

## Uso rápido

No início da aula (preparação do ambiente, primeiros minutos):

```bash
wget -O setup-ambiente.sh \
  https://raw.githubusercontent.com/peotta/lab-wireshark-unb/main/scripts/setup-ambiente.sh
chmod +x setup-ambiente.sh
./setup-ambiente.sh
```

Isso configura o grupo `wireshark` (captura sem root), instala `vsftpd` e `hping3`,
cria o usuário de teste `aluno_teste`, e já baixa o `login_server.py`.

Durante a aula, quando o roteiro pedir o script do Módulo 3 (caso não tenha rodado o
setup antes), basta:

```bash
wget https://raw.githubusercontent.com/peotta/lab-wireshark-unb/main/scripts/login_server.py
python3 login_server.py
```

## Conteúdo

- [`roteiro-curso-wireshark-2h.md`](./roteiro-curso-wireshark-2h.md) - roteiro do instrutor: módulo a módulo, com tempos sugeridos e checklist de preparação
- [`roteiro-aluno.md`](./roteiro-aluno.md) - roteiro do aluno: mesmo conteúdo prático, sem marcação de tempo, com tabela de referência de comandos e filtros no final
- [`apresentacao-wireshark-unb.pdf`](./apresentacao-wireshark-unb.pdf) - slides da aula, um por atividade do roteiro
- [`scripts/setup-ambiente.sh`](./scripts/setup-ambiente.sh) - preparação de VM (primeiro passo da aula)
- [`scripts/login_server.py`](./scripts/login_server.py) - servidor HTTP minimalista usado no Módulo 3 (credenciais em texto claro)

## Regra de ouro

Todo o tráfego "ofensivo" (força bruta, SYN flood, spoofing de IP) do roteiro é
executado **exclusivamente contra `localhost`/`127.0.0.1`** - nunca contra `unb.br`,
a máquina de um colega, ou qualquer outro host da rede.
