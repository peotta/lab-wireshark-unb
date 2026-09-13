# Análise de Pacotes na Prática com Wireshark
## Roteiro do aluno - Laboratório Kali Linux

**Formato:** aula única, 100% prática. Foco em manuseio da ferramenta e leitura de tráfego real.
**Pré-requisito do ambiente:** sua VM Kali Linux funcional, com acesso à internet.

**Dois tipos de alvo, sem Docker:**
1. **Tráfego real:** o site `unb.br`, acessado normalmente via navegador/curl (DNS, TCP, TLS).
2. **Tráfego simulado:** um serviço simples que você mesmo sobe na sua máquina (FTP nativo ou um servidor HTTP em Python puro), usado para demonstrar cenários que HTTPS real não deixa mostrar, como credenciais em texto claro.

**Wireshark:** já vem instalado por padrão no Kali. Se não estiver: `sudo apt install wireshark -y`.
**Repositório do laboratório:** `github.com/peotta/lab-wireshark-unb`. Todo script citado neste roteiro pode ser baixado com `wget` direto de lá, sem precisar copiar/colar código.

> **Regra de ouro, vale para o roteiro inteiro:** qualquer simulação de credenciais, força bruta, negação de serviço ou spoofing acontece **exclusivamente contra `localhost`/`127.0.0.1`**, o serviço que você mesmo subiu. Nunca contra `unb.br`, a máquina de um colega, ou qualquer outro host da rede.

---

## 0. Preparação do ambiente

### 0.1 Permissão de captura sem root
```bash
sudo usermod -aG wireshark $USER
sudo dpkg-reconfigure wireshark-common   # escolher "Yes" para non-superuser capture
# logout/login (ou newgrp wireshark) para a mudança de grupo valer
```
Isso é feito logo no início da aula, antes de partir para os módulos práticos. Se não funcionar na hora, o plano B é `sudo wireshark`.

### 0.2 Identificar a interface certa
```bash
ip a          # identificar a interface com IP de internet (eth0, wlan0, enp0s3...)
ping -c 2 unb.br
```
Para o serviço local dos módulos seguintes, a captura acontece na interface **Loopback: lo** (quando acessado via `127.0.0.1` ou `localhost`).

### 0.3 Preparar o serviço local
Preparação completa em um comando só (recomendado):
```bash
wget https://raw.githubusercontent.com/peotta/lab-wireshark-unb/main/scripts/setup-ambiente.sh
chmod +x setup-ambiente.sh
./setup-ambiente.sh
```
Esse script configura o grupo `wireshark`, instala `vsftpd` e `hping3`, cria o usuário `aluno_teste`, e baixa o `login_server.py`.

Se preferir rodar cada peça manualmente:

**Opção A, FTP nativo (vsftpd):**
```bash
sudo apt install vsftpd -y
sudo systemctl start vsftpd
sudo useradd -m aluno_teste
echo "aluno_teste:SenhaSuperSecreta123" | sudo chpasswd
```

**Opção B, servidor HTTP simples em Python puro:**
```bash
wget https://raw.githubusercontent.com/peotta/lab-wireshark-unb/main/scripts/login_server.py
python3 login_server.py
```

### 0.4 (Opcional) Decifrar o próprio HTTPS com SSLKEYLOGFILE
Útil para o Módulo 2 (tráfego real em `unb.br`). Navegadores modernos exportam as chaves de sessão TLS se a variável `SSLKEYLOGFILE` estiver definida **antes** de abrir o navegador:
```bash
export SSLKEYLOGFILE=~/tls-keys.log
firefox &
```
No Wireshark: `Edit > Preferences > Protocols > TLS > (Pre)-Master-Secret log filename`, apontar para `~/tls-keys.log`.

### 0.5 Checklist antes de começar
- [ ] Wireshark abre sem erro de permissão
- [ ] `curl -I https://unb.br` responde normalmente
- [ ] O serviço local escolhido (vsftpd ou `login_server.py`) sobe sem erro e responde em `localhost`
- [ ] Interface `lo` aparece na lista de interfaces do Wireshark

---

## Módulo 1: Fundamentos de captura

**Objetivo:** saber iniciar/parar captura, salvar, e diferenciar filtro de captura de filtro de exibição.

### 1.1 Primeira captura guiada
1. Abrir Wireshark, selecionar a interface com internet, clicar no tubarão azul (Start).
2. Em outro terminal: `ping -c 4 unb.br`
3. Parar a captura. Observar os pacotes ICMP Echo Request/Reply e o IP público resolvido para `unb.br`.
4. Clicar em um pacote e explorar os painéis: lista de pacotes, detalhes (árvore de camadas), bytes brutos (hex).

### 1.2 Filtro de captura vs. filtro de exibição
- Filtro de **captura** (BPF, campo "Capture Filters", definido antes de iniciar): `host unb.br`, `port 443`, `icmp`
- Filtro de **exibição** (campo superior, aplicado depois): `ip.addr == <ip-do-unb.br>`, `tcp.port == 443`, `dns`, `tls`

**Exercício:** capturar enquanto navega até `https://unb.br` e aplicar:
```
dns.qry.name contains "unb.br"
tcp.port == 443
tls.handshake.type == 1     # Client Hello
```

### 1.3 Salvando e reabrindo capturas
- `File > Save As`, formato `.pcapng`
- Alternativa headless: `sudo tcpdump -i <interface> host unb.br -w captura.pcap`

---

## Módulo 2: Lendo protocolos de um site real em HTTPS

**Objetivo:** entender DNS, TCP handshake, TLS handshake e por que HTTPS não é "invisível".

### 2.1 DNS
1. Capturar enquanto roda: `dig unb.br`
2. Filtro: `dns`. Observar query/response, `dns.qry.name`, `dns.a`.

### 2.2 TCP three-way handshake
1. Capturar enquanto roda: `curl -I https://unb.br`
2. Filtro: `ip.addr == <ip-unb.br> && tcp.port == 443`
3. Identificar SYN, SYN-ACK, ACK no campo `tcp.flags`.

### 2.3 TLS handshake: o que fica visível mesmo em HTTPS
1. Filtro: `tls.handshake`
2. Abrir o **Client Hello**: mostrar a extensão **SNI**, o domínio (`unb.br`) viaja em texto claro mesmo com o resto cifrado.
3. Abrir **Server Hello** / **Certificate**: mostrar emissor, validade, algoritmo de assinatura.
4. **Follow > TCP Stream** num pacote de Application Data: o conteúdo é ilegível (cifrado). Ponto central: TLS protege o conteúdo, não os metadados.

### 2.4 (Se configurado o item 0.4) Decifrando o próprio HTTPS
1. Navegar até `https://unb.br` no navegador aberto com `SSLKEYLOGFILE` ativo.
2. Com o TLS keylog configurado nas preferências: `Follow > HTTP Stream`, o conteúdo aparece decifrado.

---

## Módulo 3: Gerador de tráfego local, simulando um cenário inseguro

**Objetivo:** capturar e analisar um protocolo em texto claro de ponta a ponta, algo que não dá pra mostrar contra um site HTTPS real.

### 3.1 Subindo o serviço
```bash
python3 login_server.py     # Opção B
# ou, se escolheu FTP:
sudo systemctl start vsftpd  # Opção A
```

### 3.2 Capturando um login legítimo
1. Iniciar captura na interface **Loopback: lo**.
2. Em outro terminal:
```bash
curl -d "user=admin&pass=SenhaSuperSecreta123" http://localhost:8080/
# ou, para FTP:
ftp localhost   # usuário/senha de teste
```
3. Filtro: `http.request.method == "POST"` (ou `ftp`)
4. **Follow > TCP Stream**: usuário e senha aparecem em texto claro.

**Discussão:** compare com o Módulo 2, mesmo protocolo (requisição/resposta), mas sem TLS por cima, tudo fica exposto. É exatamente essa diferença que HTTPS resolve.

---

## Módulo 4: Estudo de caso guiado

**Cenário:** "Alguém tentou adivinhar a senha do serviço local. Investigue a captura."

### Gerando o incidente (contra o seu próprio serviço)
```bash
for pass in 123456 senha admin SenhaSuperSecreta123; do
  curl -s -d "user=admin&pass=$pass" http://localhost:8080/ > /dev/null
done
```

### Investigando a captura
1. Filtro: `http.request.method == "POST"`
2. **Follow > HTTP Stream** em cada tentativa até achar a que teve sucesso ("Login OK").
3. Responder:
   - Quantas tentativas houve e em qual intervalo de tempo?
   - Qual foi a senha que funcionou?
   - Que evidência no pcap comprova o sucesso do login?

---

## Módulo 5: Simulando uma negação de serviço (DoS) contra a própria máquina

> **Repita para si mesmo:** o alvo é **sempre `localhost`/`127.0.0.1`, nunca outro IP**. Nem `unb.br`, nem a máquina do colega ao lado, nem o gateway da rede do laboratório.

**Objetivo:** reconhecer no Wireshark a diferença visual entre tráfego normal e um volume anômalo de pacotes característico de negação de serviço.

### 5.1 Preparação
- Recomendado: tirar um snapshot da VM antes (`VirtualBox > Machine > Take Snapshot`), a VM pode ficar temporariamente lenta ou travar durante o teste, isso é esperado.
- Manter o `login_server.py` (ou vsftpd) do Módulo 3 rodando.
- `hping3` já vem instalado por padrão no Kali (`which hping3` para confirmar).

### 5.2 Linha de base: como é um SYN normal
1. Iniciar captura na interface **Loopback: lo**.
2. Rodar `curl http://localhost:8080/` uma vez.
3. Filtro: `tcp.flags.syn == 1`, observar **um** SYN e o handshake completo.

### 5.3 Gerando o flood
```bash
# Opção 1: manual, controlado no Ctrl+C
sudo hping3 -S -p 8080 --flood localhost
```
- Deixar rodar por **no máximo 10 a 15 segundos** e então `Ctrl+C` para parar.
- Enquanto isso, tentar em outro terminal: `curl -m 3 http://localhost:8080/`, observar que o serviço fica lento ou não responde dentro do timeout.

**Opção 2: quantidade fixa de pacotes (reprodutível, para automaticamente):**
```bash
sudo hping3 -S -p 8080 -c 2000 --flood localhost
```
Envia exatamente 2000 pacotes SYN o mais rápido possível e encerra sozinho — todo aluno gera a mesma quantidade, o que facilita comparar os números depois no Statistics > Conversations.

**Opção 3: taxa controlada (flood "moderado", sem `--flood`):**
```bash
sudo hping3 -S -p 8080 -c 2000 -i u1000 localhost
```
`-i u1000` manda um pacote a cada 1000 microssegundos (1ms) — ritmo fixo em vez de "o mais rápido possível". Bom para comparar com a Opção 2 e discutir a diferença entre volume total e taxa de envio.

### 5.4 Analisando a captura
1. Parar a captura no Wireshark.
2. Filtro: `tcp.flags.syn == 1 && tcp.flags.ack == 0`, observar o volume enorme de SYN, todos com a mesma origem (`127.0.0.1`), sem handshake completo correspondente.
3. **Statistics > IO Graph**: pico abrupto de pacotes/segundo comparado ao tráfego normal capturado antes.
4. **Statistics > Conversations** (aba TCP): dezenas/centenas de conexões half-open para a mesma porta.

**Discussão:**
- Por que um volume alto de SYN sem ACK final esgota recursos do servidor?
- Por que isso é visualmente muito diferente do login legítimo do Módulo 3? Não é sobre o *conteúdo* do pacote, é sobre o *padrão*.
- Como uma ferramenta de defesa (firewall, IDS, rate limiting) usaria esse mesmo padrão para detectar e bloquear automaticamente?

### 5.5 Encerrando o ambiente
```bash
sudo pkill hping3
```

---

## Encerramento
- Fluxo mental: **Capturar → Filtrar → Seguir o stream → Correlacionar com estatísticas**
- Três padrões vistos na aula: tráfego real cifrado (Módulo 2), credencial em texto claro (Módulo 3), volume anômalo de negação de serviço (Módulo 5), cada um com uma assinatura diferente no Wireshark
- Limite ético: simulações de credenciais e de DoS só contra serviço/máquina próprios, nunca contra `unb.br`, colegas ou qualquer infraestrutura de terceiros
- Próximos passos: `wireshark.org/docs`, wiki.wireshark.org/SampleCaptures (pcaps de exemplo reais), e o livro *Practical Packet Analysis* (Chris Sanders)

---

## Tabela de referência: comandos e filtros

### Comandos de terminal

| Comando | Para que serve |
|---|---|
| `ip a` | Listar interfaces de rede e identificar qual usar na captura |
| `ping -c 4 unb.br` | Gerar tráfego ICMP simples |
| `dig unb.br` / `nslookup unb.br` | Forçar uma consulta DNS |
| `curl -I https://unb.br` | Gerar handshake TCP/TLS sem baixar a página inteira |
| `curl -IL http://unb.br` | Seguir redirecionamento HTTP → HTTPS |
| `sudo tcpdump -i <if> -w arquivo.pcap` | Captura headless, sem abrir a interface gráfica |
| `python3 login_server.py` | Subir o serviço HTTP local de simulação (Módulo 3) |
| `ftp localhost` | Testar o serviço FTP local de simulação (Módulo 3, Opção A) |
| `curl -d "user=X&pass=Y" http://localhost:8080/` | Simular um login no serviço local |
| `sudo hping3 -S -p 8080 --flood localhost` | Gerar SYN flood contra o próprio serviço (Módulo 5) |
| `sudo hping3 -S -p 8080 -c 2000 --flood localhost` | SYN flood com quantidade fixa de pacotes, para sozinho |
| `sudo hping3 -S -p 8080 --rand-source --flood localhost` | Simular spoofing de IP de origem no flood |
| `sudo pkill hping3` | Encerrar o flood |
| `export SSLKEYLOGFILE=~/tls-keys.log` | Preparar o navegador para exportar chaves TLS (Módulo 2.4) |

### Operadores de filtro de exibição

| Operador | Símbolo alternativo | Significado | Exemplo |
|---|---|---|---|
| `==` | `eq` | Igual a | `tcp.port == 443` |
| `!=` | `ne` | Diferente de | `ip.addr != 192.168.0.1` |
| `>` | `gt` | Maior que | `frame.len > 1000` |
| `<` | `lt` | Menor que | `tcp.analysis.ack_rtt < 0.05` |
| `>=` | `ge` | Maior ou igual a | `tcp.flags.syn >= 1` |
| `<=` | `le` | Menor ou igual a | `http.response.code <= 299` |
| `contains` | | O campo contém um valor (texto ou bytes) | `dns.qry.name contains "unb.br"` |
| `matches` | | O campo bate com uma expressão regular | `http.request.uri matches "^/login"` |
| `&&` | `and` | E (as duas condições precisam ser verdadeiras) | `tcp.port == 443 && ip.addr == 10.0.0.5` |
| `\|\|` | `or` | Ou (pelo menos uma condição verdadeira) | `dns \|\| arp` |
| `!` | `not` | Nega a condição | `!(tcp.port == 22)` |
| `in` | | O valor está dentro de um conjunto | `tcp.port in {80, 443, 8080}` |

### Filtros de exibição do Wireshark

| Filtro | Para que serve |
|---|---|
| `dns` | Mostrar só tráfego DNS |
| `dns.qry.name contains "unb.br"` | Consultas DNS relacionadas ao domínio |
| `tcp.port == 443` | Tráfego numa porta específica |
| `ip.addr == <ip>` | Tráfego de/para um IP específico |
| `tls.handshake` | Todo o handshake TLS |
| `tls.handshake.type == 1` | Apenas o pacote Client Hello |
| `tls.handshake.extensions_server_name contains "unb.br"` | TLS filtrado pelo domínio no SNI |
| `http.request` | Todas as requisições HTTP |
| `http.request.method == "POST"` | Só envios de formulário/login |
| `http.response.code >= 400` | Respostas HTTP de erro |
| `tcp.flags.syn == 1` | Todos os pacotes SYN |
| `tcp.flags.syn == 1 && tcp.flags.ack == 0` | Só SYN sem handshake completo (varredura ou flood) |
| `tcp.analysis.retransmission` | Retransmissões (indício de perda/latência) |
| `tcp.analysis.ack_rtt > 0.2` | Round-trip alto (possível latência) |
| `arp` | Tráfego ARP |

### Recursos do menu Statistics

| Recurso | Para que serve |
|---|---|
| Protocol Hierarchy | Visão geral de quais protocolos dominam a captura |
| Conversations | Quem fala com quem, quantos bytes, quantas conexões |
| Endpoints | Lista de todos os IPs vistos na captura |
| IO Graph | Picos de tráfego ao longo do tempo |
| Flow Graph | Linha do tempo visual de um handshake TCP/TLS |

### Menu de análise de fluxo

| Ação | Para que serve |
|---|---|
| Follow > TCP Stream | Reconstruir a conversa completa de uma conexão TCP |
| Follow > HTTP Stream | Reconstruir a requisição/resposta HTTP (ou HTTP decifrado, se houver TLS keylog) |
