#!/usr/bin/env bash
# Preparacao do ambiente do laboratorio de Wireshark.
# Rodar UMA VEZ, na vespera da aula (ou na criacao da imagem da VM) -- nao durante a aula.
set -e

echo "== Preparando ambiente do laboratorio de Wireshark =="

echo "-- Grupo wireshark (captura sem root) --"
if groups "$USER" | grep -q '\bwireshark\b'; then
    echo "Usuario $USER ja esta no grupo wireshark."
else
    sudo usermod -aG wireshark "$USER"
    echo "Usuario $USER adicionado ao grupo wireshark."
    echo "IMPORTANTE: faca logout/login (ou reinicie a VM) para a mudanca valer."
fi

echo "-- vsftpd (Opcao A do Modulo 3) --"
if ! command -v vsftpd &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y vsftpd
    echo "vsftpd instalado."
else
    echo "vsftpd ja disponivel."
fi
sudo systemctl enable --now vsftpd
if ! id "aluno_teste" &>/dev/null; then
    sudo useradd -m aluno_teste
    echo "aluno_teste:SenhaSuperSecreta123" | sudo chpasswd
    echo "Usuario aluno_teste criado (senha: SenhaSuperSecreta123)."
else
    echo "Usuario aluno_teste ja existe."
fi

echo "-- hping3 (Modulos 5 e 5.6) --"
if ! command -v hping3 &> /dev/null; then
    sudo apt-get install -y hping3
else
    echo "hping3 ja disponivel."
fi

echo "-- openssh-server (captura de trafego SSH) --"
if ! command -v sshd &>/dev/null; then
    sudo apt-get install -y openssh-server
    echo "openssh-server instalado."
else
    echo "openssh-server ja disponivel."
fi
sudo systemctl enable --now ssh

# Teste: porta 22 escutando
if ss -tlnp | grep -q ':22'; then
    echo "OK: SSH ativo na porta 22."
else
    echo "AVISO: SSH nao esta escutando na porta 22 -- verifique manualmente."
fi

echo "-- login_server.py (Opcao B do Modulo 3) --"
wget -q -O login_server.py \
  https://raw.githubusercontent.com/peotta/lab-wireshark-unb/main/scripts/login_server.py
chmod +x login_server.py
echo "login_server.py baixado em $(pwd)/login_server.py"

echo ""
echo "== Ambiente pronto. =="
echo "Checklist antes da aula:"
echo "  1) Confirmar que o logout/login para o grupo wireshark foi feito"
echo "  2) 'python3 login_server.py' sobe sem erro"
echo "  3) 'sudo systemctl status vsftpd' mostra ativo"
echo "  4) 'which hping3' encontra o binario"
