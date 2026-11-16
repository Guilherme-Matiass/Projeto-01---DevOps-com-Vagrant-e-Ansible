#!/bin/bash
echo "Configurando /etc/hosts..."
if ! grep -q "guilherme.bruno.devops" /etc/hosts; then
    echo -e "192.168.56.112 arq.guilherme.bruno.devops\n192.168.56.114 app.guilherme.bruno.devops\n192.168.56.124 db.guilherme.bruno.devops\n192.168.56.60 cli.guilherme.bruno.devops" | sudo tee -a /etc/hosts > /dev/null
fi

echo "Limpando e registrando chaves SSH..."
ssh-keyscan -H arq.guilherme.bruno.devops app.guilherme.bruno.devops db.guilherme.bruno.devops cli.guilherme.bruno.devops 192.168.56.112 192.168.56.114 192.168.56.124 192.168.56.60 >> ~/.ssh/known_hosts 2>/dev/null

echo "Ambiente pronto para o teste!"
