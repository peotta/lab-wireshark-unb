# Análise de Pacotes na Prática com Wireshark
## Roteiro de curso prático - 2 horas - Laboratório Kali Linux

**Formato:** aula única, 100% prática, sem avaliação formal. Foco em manuseio da ferramenta e leitura de tráfego real, não em teoria de protocolos.
**Pré-requisito do ambiente:** cada aluno com sua VM Kali Linux funcional, com acesso à internet.
**Dois tipos de alvo, sem Docker:**
1. **Tráfego real** - o site `unb.br`, acessado normalmente via navegador/curl (DNS, TCP, TLS).
2. **Tráfego simulado** - um serviço simples que o próprio aluno sobe na sua máquina (FTP nativo ou um servidor HTTP em Python puro), usado para demonstrar cenários que HTTPS real não deixa mostrar, como credenciais em texto claro.

**Wireshark:** já vem instalado por padrão no Kali. Se não estiver: `sudo apt install wireshark -y`.
**Repositório do laboratório:** `github.com/peotta/lab-wireshark-unb` - todo script citado neste roteiro pode ser baixado com `wget` direto de lá, sem precisar copiar/colar código.

> **Nota ética/legal:** contra `unb.br` só é usado tráfego de navegação legítima (DNS, TLS, HTTP normal). Qualquer simulação de credenciais/força bruta acontece **contra um serviço que o próprio aluno sobe na própria máquina** - nunca contra `unb.br` ou qualquer infraestrutura de terceiros.

---

## 0. Preparação do ambiente (primeiros 10 min da aula)

### 0.1 Permissão de captura sem root
```bash
sudo usermod -aG wireshark $USER
sudo dpkg-reconfigure wireshark-common   # escolher "Yes" para non-superuser capture
# logout/login (ou newgrp wireshark) para a mudança de grupo valer
```

Isso é feito no início da aula, junto com o resto da preparação do ambiente (Seção 0.3). No checklist de abertura (0.5), teste rápido: abra o Wireshark e veja se a lista de interfaces aparece sem erro de permissão.

**Plano B, se algum aluno chegar à aula sem esse setup funcionando:** simplesmente rodar
```bash
sudo wireshark
```
para aquele aluno específico, sem parar a turma toda. Vale uma nota de rodapé rápida (10 segundos) explicando que isso é um atalho aceitável dentro de uma VM de laboratório descartável, mas que em ambiente de produção real o certo é configurar o grupo `wireshark` - para não passar a mensagem errada de que "rodar como root é o normal".

### 0.2 Identificar a interface certa
```bash
ip a          # identificar a interface com IP de internet (eth0, wlan0, enp0s3...)
ping -c 2 unb.br
```
Para o serviço local do Módulo 3, a captura acontece na interface **Loopback: lo** (quando acessado via `127.0.0.1` ou `localhost`) - o Wireshark lista essa interface junto com as demais.

### 0.3 Servidor local de simulação (sem Docker)
Todo o código do laboratório (script de setup + `login_server.py`) está publicado em
**`github.com/peotta/lab-wireshark-unb`**. O aluno não precisa copiar/colar nada - só
baixar com `wget` no momento de usar. Duas opções de alvo, escolha uma (ou deixe as
duas prontas e decida na hora):

**Opção A - FTP nativo (vsftpd):**
```bash
sudo apt install vsftpd -y
sudo systemctl start vsftpd
# autentica com o próprio usuário do sistema (ou crie um usuário de teste)
sudo useradd -m aluno_teste
echo "aluno_teste:SenhaSuperSecreta123" | sudo chpasswd
```

**Opção B - servidor HTTP simples em Python puro, com form de login:**
```bash
wget https://raw.githubusercontent.com/peotta/lab-wireshark-unb/main/scripts/login_server.py
python3 login_server.py
```
Sem dependências extras, só Python 3 (já vem no Kali). O código-fonte comentado está
no repositório, para quem quiser ler antes de rodar.

**Preparação completa em um comando (recomendado, primeiro passo da aula):**
```bash
wget https://raw.githubusercontent.com/peotta/lab-wireshark-unb/main/scripts/setup-ambiente.sh
chmod +x setup-ambiente.sh
./setup-ambiente.sh
```
Esse script sozinho já configura o grupo `wireshark`, instala `vsftpd` e `hping3`, cria
o `aluno_teste`, e baixa o `login_server.py` - cobre a preparação inteira das Seções
0.1, 0.3 e 5.1 de uma vez.

### 0.4 (Opcional) Decifrar o próprio HTTPS com SSLKEYLOGFILE
Útil só para o Módulo 2 (tráfego real em `unb.br`). Navegadores modernos exportam as chaves de sessão TLS se a variável `SSLKEYLOGFILE` estiver definida **antes** de abrir o navegador:
```bash
export SSLKEYLOGFILE=~/tls-keys.log
firefox &
```
No Wireshark: `Edit → Preferences → Protocols → TLS → (Pre)-Master-Secret log filename` → apontar para `~/tls-keys.log`.

### 0.5 Checklist de abertura da aula
- [ ] Wireshark abre sem erro de permissão
- [ ] `curl -I https://unb.br` responde normalmente
- [ ] O serviço local escolhido (vsftpd ou `login_server.py`) sobe sem erro e responde em `localhost`
- [ ] Interface `lo` aparece na lista de interfaces do Wireshark

---

## Módulo 1 - Fundamentos de captura (20 min)

**Objetivo:** o aluno sai sabendo iniciar/parar captura, salvar, e diferenciar filtro de captura de filtro de exibição.

### 1.1 Primeira captura guiada
1. Abrir Wireshark → selecionar a interface com internet → clicar no tubarão azul (Start).
2. Em outro terminal: `ping -c 4 unb.br`
3. Parar a captura. Mostrar os pacotes ICMP Echo Request/Reply e o IP público resolvido para `unb.br`.
4. Clicar em um pacote → explorar os painéis: lista de pacotes, detalhes (árvore de camadas), bytes brutos (hex).

### 1.2 Filtro de captura vs. filtro de exibição
- Filtro de **captura** (BPF, campo "Capture Filters", definido antes de iniciar): `host unb.br`, `port 443`, `icmp`
- Filtro de **exibição** (campo superior, aplicado depois): `ip.addr == <ip-do-unb.br>`, `tcp.port == 443`, `dns`, `tls`

**Exercício rápido (5 min):** capturar enquanto navega até `https://unb.br` e aplicar:
```
dns.qry.name contains "unb.br"
tcp.port == 443
tls.handshake.type == 1     # Client Hello
```

### 1.3 Salvando e reabrindo capturas
- `File → Save As` → formato `.pcapng`
- Alternativa headless: `sudo tcpdump -i <interface> host unb.br -w captura.pcap`

---

## Módulo 2 - Lendo protocolos de um site real em HTTPS (20 min)

**Objetivo:** entender DNS, TCP handshake, TLS handshake e por que HTTPS não é "invisível".

### 2.1 DNS
1. Capturar enquanto roda: `dig unb.br`
2. Filtro: `dns` → mostrar query/response, `dns.qry.name`, `dns.a`.

### 2.2 TCP three-way handshake
1. Capturar enquanto roda: `curl -I https://unb.br`
2. Filtro: `ip.addr == <ip-unb.br> && tcp.port == 443`
3. Identificar SYN → SYN,ACK → ACK no campo `tcp.flags`.

### 2.3 TLS handshake - o que fica visível mesmo em HTTPS
1. Filtro: `tls.handshake`
2. Abrir o **Client Hello** → mostrar a extensão **SNI**: o domínio (`unb.br`) viaja em texto claro mesmo com o resto cifrado.
3. Abrir **Server Hello** / **Certificate** → mostrar emissor, validade, algoritmo de assinatura.
4. **Follow → TCP Stream** num pacote de Application Data → mostrar que o conteúdo é ilegível (cifrado). Ponto de ensino central: TLS protege o conteúdo, não os metadados.

### 2.4 (Se configurado o item 0.4) Decifrando o próprio HTTPS
1. Navegar até `https://unb.br` no navegador aberto com `SSLKEYLOGFILE` ativo.
2. Com o TLS keylog configurado nas preferências: `Follow → HTTP Stream` → o conteúdo aparece decifrado.

---

## Módulo 3 - Gerador de tráfego local: simulando um cenário inseguro (20 min)

**Objetivo:** capturar e analisar um protocolo em texto claro de ponta a ponta - coisa que não dá pra mostrar contra um site HTTPS real.

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
4. **Follow → TCP Stream** → mostrar usuário e senha em texto claro.

**Discussão guiada (3 min):** compare com o Módulo 2 - mesmo protocolo (requisição/resposta), mas sem TLS por cima, tudo fica exposto. É exatamente essa diferença que HTTPS resolve.

### 3.3 Kit de filtros de exibição úteis (vale para tráfego local e real)
```
tcp.flags.syn == 1 && tcp.flags.ack == 0     # apenas pacotes SYN
tcp.analysis.retransmission                  # retransmissões
http.request                                 # requisições HTTP
http.response.code >= 400                    # respostas de erro
tls.handshake.extensions_server_name contains "unb.br"   # tráfego TLS pro domínio certo
```

### 3.4 Estatísticas embutidas (Statistics menu)
- **Protocol Hierarchy** - quais protocolos dominam a captura
- **Conversations** - quem fala com quem, quantos bytes
- **IO Graph** - picos de tráfego ao longo do tempo
- **Flow Graph** - linha do tempo visual do handshake TCP/TLS

---

## Módulo 4 - Estudo de caso guiado (15 min)

**Cenário:** "Alguém tentou adivinhar a senha do serviço local. Investigue a captura."

### Passo a passo do instrutor (o aluno gera o próprio incidente, contra o próprio serviço)
```bash
for pass in 123456 senha admin SenhaSuperSecreta123; do
  curl -s -d "user=admin&pass=$pass" http://localhost:8080/ > /dev/null
done
```

### Passo a passo do aluno (investigar a captura)
1. Filtro: `http.request.method == "POST"`
2. **Follow → HTTP Stream** em cada tentativa até achar a que teve sucesso ("Login OK").
3. Responder por escrito (num papel ou chat da turma, sem entregável formal):
   - Quantas tentativas houve e em qual intervalo de tempo?
   - Qual foi a senha que funcionou?
   - Que evidência no pcap comprova o sucesso do login?

---

## Módulo 5 - Simulando uma negação de serviço (DoS) contra a própria máquina (20 min)

> **Regra de ouro deste módulo, repetir em voz alta para a turma:** o alvo é **sempre `localhost`/`127.0.0.1`, nunca outro IP** - nem `unb.br`, nem a máquina do colega ao lado, nem o gateway da rede do laboratório. É um exercício de "atacar a si mesmo" para entender a assinatura de tráfego no Wireshark, não uma ferramenta pra sair testando por aí.

**Objetivo:** reconhecer no Wireshark a diferença visual entre tráfego normal e um volume anômalo de pacotes característico de negação de serviço - volume alto, mesma origem, handshakes incompletos.

### 5.1 Preparação
- Recomendado: tirar um snapshot da VM antes (`VirtualBox → Machine → Take Snapshot`), porque a VM pode ficar temporariamente lenta ou travar durante o teste - isso é esperado e faz parte do que estamos demonstrando.
- Manter o `login_server.py` (ou vsftpd) do Módulo 3 rodando.
- `hping3` já vem instalado por padrão no Kali (`which hping3` para confirmar).

### 5.2 Linha de base: como é um SYN normal
1. Iniciar captura na interface **Loopback: lo**.
2. Rodar `curl http://localhost:8080/` uma vez.
3. Filtro: `tcp.flags.syn == 1` → mostrar **um** SYN e o handshake completo (SYN → SYN,ACK → ACK).

### 5.3 Gerando o flood (SYN flood contra o próprio serviço)
```bash
sudo hping3 -S -p 8080 --flood localhost
```
- Deixar rodar por **no máximo 10-15 segundos** e então `Ctrl+C` para parar.
- Enquanto isso, tentar em outro terminal: `curl -m 3 http://localhost:8080/` → mostrar que o serviço fica lento ou não responde dentro do timeout.

### 5.4 Analisando a captura
1. Parar a captura no Wireshark.
2. Filtro: `tcp.flags.syn == 1 && tcp.flags.ack == 0` → mostrar o volume enorme de SYN, todos com a mesma origem (`127.0.0.1`), sem handshake completo correspondente.
3. **Statistics → IO Graph** → mostrar o pico abrupto de pacotes/segundo em comparação com o tráfego normal capturado antes.
4. **Statistics → Conversations** (aba TCP) → mostrar dezenas/centenas de conexões half-open para a mesma porta.

**Discussão guiada (3 min):**
- Por que um volume alto de SYN sem ACK final esgota recursos do servidor (fila de conexões half-open)?
- Por que isso é visualmente muito diferente do login legítimo do Módulo 3 - não é sobre o *conteúdo* do pacote, é sobre o *padrão* (volume, repetição, origem única)?
- Contraste rápido: como uma ferramenta de defesa (firewall, IDS, rate limiting) usaria exatamente esse padrão (muitos SYN da mesma origem, sem ACK) para detectar e bloquear automaticamente?

### 5.5 Encerrando o ambiente
```bash
# conferir se algum processo hping3 ainda está rodando e finalizar
sudo pkill hping3
```

---

## Encerramento (5 min)
- Recapitular o fluxo mental: **Capturar → Filtrar → Seguir o stream → Correlacionar com estatísticas**
- Recapitular os três padrões vistos na aula: tráfego real cifrado (Módulo 2), credencial em texto claro (Módulo 3), e volume anômalo de negação de serviço (Módulo 5) - cada um com uma "assinatura" diferente no Wireshark
- Reforçar o limite ético: simulações de credenciais e de DoS só contra serviço/máquina próprios, nunca contra `unb.br`, colegas ou qualquer infraestrutura de terceiros
- Indicar próximos passos: `wireshark.org/docs`, wiki.wireshark.org/SampleCaptures (pcaps de exemplo reais), e o livro *Practical Packet Analysis* (Chris Sanders)
- Deixar o kit de filtros (seção 3.3) disponível como "cola" para os alunos

---

## Checklist final para você, instrutor
- [ ] Testar `login_server.py` (ou vsftpd) e todos os exercícios na sua própria VM antes da aula
- [ ] Testar os passos contra `unb.br` também - sites reais mudam certificado/CDN com o tempo
- [ ] Confirmar que `hping3` está disponível em todas as VMs (`which hping3`) e orientar os alunos a tirarem snapshot da VM antes do Módulo 5
- [ ] Deixar bem claro, verbalmente e por escrito no material, que o alvo do Módulo 5 é sempre `localhost` - nunca outro host da rede do laboratório
- [ ] Ter um `.pcapng` de backup pré-gravado de cada exercício (incluindo o SYN flood), caso algum aluno tenha problema de ambiente
- [ ] Se for usar o Módulo 2.4 (SSLKEYLOGFILE), testar num navegador limpo antes - alguns navegadores corporativos bloqueiam essa variável por política
