# Persistência de Dados e Gerenciamento de Volumes em Containers Docker

*Aluno:* Kauan Fernandes Oliveira  
*Disciplina:* Infraestrutura e Serviços de TI  
*Instituição:* Facens  
*Data:* Maio de 2026  

---

## 1. Introdução

Containers Docker são, por padrão, *efêmeros**: quando removidos, todos os dados gerados internamente são perdidos permanentemente. Esse comportamento é adequado para aplicações *stateless* (como servidores web que apenas respondem requisições), porém inaceitável para bancos de dados, sistemas de arquivos e qualquer serviço que precise preservar estado entre reinicializações.

**Persistência de dados** é a capacidade de garantir que informações geradas por uma aplicação sobrevivam ao ciclo de vida do container. O mecanismo técnico que torna isso possível são os **Volumes Docker** — áreas de armazenamento gerenciadas separadamente do container, que existem independentemente de qualquer container estar rodando ou não.

### Containers Efêmeros

Por padrão, o sistema de arquivos de um container é temporário. Ao remover ou reiniciar um container, todos os arquivos criados dentro dele (logs, uploads, arquivos de banco de dados) são perdidos para sempre. Isso ocorre porque o Docker utiliza uma camada de escrita temporária sobre a imagem, que é descartada junto com o container.

### Importância dos Volumes

Os volumes resolvem esse problema ao armazenar dados **fora** do ciclo de vida do container, em um local gerenciado pelo Docker no sistema host. Isso permite:

- Persistir dados de bancos de dados após reinicializações
- Compartilhar dados entre múltiplos containers
- Realizar backups e restaurações de forma independente
- Atualizar containers sem perder dados

### Objetivo da Atividade

Esta atividade tem como objetivo desenvolver a capacidade de compreender, implementar e validar mecanismos de persistência de dados em ambientes containerizados utilizando Docker, aplicando conceitos de Named Volumes, Bind Mounts, backup, restauração e automação de infraestrutura.

---

## 2. Ambiente Utilizado

| Item | Versão / Informação |
|------|-------------------|
| Sistema Operacional | Ubuntu 22.04.5 LTS (Jammy) |
| Docker Engine | 29.5.0, build 98f1464 |
| Docker Compose | v5.1.3 |
| Processador (vCPUs) | 2 núcleos |
| Memória RAM | 1,9 GiB |
| Swap | 2,6 GiB |
| Virtualização | Oracle VirtualBox |

---

## 3. Desenvolvimento da Atividade

### Cenário 1 — Persistência de Dados com MySQL e Named Volume

**Objetivo:** Validar que os dados sobrevivem à remoção do container.

**Comandos utilizados:**

```bash
# Criar volume nomeado
docker volume create mysql-prod-data

# Criar container MySQL com volume persistente
docker run -d \
  --name mysql-persistente \
  -e MYSQL_ROOT_PASSWORD=root123 \
  -e MYSQL_DATABASE=meuapp \
  -e MYSQL_USER=appuser \
  -e MYSQL_PASSWORD=app123 \
  -v mysql-prod-data:/var/lib/mysql \
  -p 3306:3306 \
  mysql:8.0

# Conectar ao MySQL e criar tabela com dados
docker exec -it mysql-persistente mysql -uroot -proot123

# Dentro do MySQL:
CREATE DATABASE IF NOT EXISTS teste;
USE teste;
CREATE TABLE usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100),
  email VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO usuarios (nome, email) VALUES
  ('João Silva', 'joao@email.com'),
  ('Maria Santos', 'maria@email.com'),
  ('Pedro Costa', 'pedro@email.com');
SELECT * FROM usuarios;

# Remover container (simulando desastre)
docker stop mysql-persistente
docker rm mysql-persistente

# Verificar que o volume ainda existe
docker volume ls | grep mysql-prod-data

# Recriar container com o mesmo volume
docker run -d \
  --name mysql-restaurado \
  -e MYSQL_ROOT_PASSWORD=root123 \
  -v mysql-prod-data:/var/lib/mysql \
  -p 3306:3306 \
  mysql:8.0

# Validar persistência dos dados
docker exec -it mysql-restaurado mysql -uroot -proot123 -e "USE teste; SELECT * FROM usuarios;"
```

**Explicação técnica:** O flag `-v mysql-prod-data:/var/lib/mysql` mapeia o volume nomeado para o diretório interno de dados do MySQL. Ao remover o container, o volume permanece intacto no host gerenciado pelo Docker. Um novo container apontando para o mesmo volume encontra todos os dados preservados, demonstrando a separação entre o ciclo de vida do container e o ciclo de vida dos dados.

---

### Cenário 2 — Backup e Restauração de Volume

**Objetivo:** Compreender estratégias de backup e recuperação de dados.

**Comandos utilizados:**

```bash
# Backup físico via tar.gz
docker run --rm \
  -v mysql-prod-data:/dados \
  -v $(pwd)/backups:/backup \
  alpine \
  tar czf /backup/mysql-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /dados .

# Backup lógico via mysqldump
docker exec mysql-restaurado \
  mysqldump -uroot -proot123 --all-databases > backups/backup-completo.sql

docker exec mysql-restaurado \
  mysqldump -uroot -proot123 teste > backups/backup-teste.sql

# Simular perda total
docker stop mysql-restaurado
docker rm mysql-restaurado
docker volume rm mysql-prod-data

# Restaurar a partir do tar.gz
docker volume create mysql-restaurado-data
docker run --rm \
  -v mysql-restaurado-data:/dados \
  -v $(pwd)/backups:/backup \
  alpine \
  sh -c "tar xzf /backup/mysql-backup-*.tar.gz -C /dados"

# Recriar container com dados restaurados
docker run -d \
  --name mysql-funcional \
  -e MYSQL_ROOT_PASSWORD=root123 \
  -v mysql-restaurado-data:/var/lib/mysql \
  -p 3306:3306 \
  mysql:8.0

# Verificar dados restaurados
docker exec -it mysql-funcional mysql -uroot -proot123 -e "USE teste; SELECT * FROM usuarios;"
```

**Explicação técnica:** Foram utilizados dois métodos de backup. O backup físico via `tar.gz` copia os arquivos binários do volume diretamente, sendo mais rápido porém dependente da versão do MySQL. O backup lógico via `mysqldump` gera um arquivo SQL portável com todos os comandos necessários para recriar a estrutura e os dados, sendo mais flexível e indicado para migrações entre versões.

---

### Cenário 3 — Bind Mount e Desenvolvimento

**Objetivo:** Compreender o funcionamento de Bind Mounts em ambientes de desenvolvimento.

**Comandos utilizados:**

```bash
# Criar diretório local
mkdir -p docker/bind-dev
cd docker/bind-dev

# Criar arquivo no host
echo "<h1>Olá do Host! Versão 1</h1>" > index.html

# Subir container Nginx com Bind Mount
docker run -d \
  --name nginx-dev \
  -v $(pwd):/usr/share/nginx/html \
  -p 8080:80 \
  nginx:alpine

# Validar acesso dentro do container
docker exec nginx-dev cat /usr/share/nginx/html/index.html

# Alterar arquivo no host e ver reflexo no container
echo "<h1>Versão 2 - Atualizado em $(date)</h1>" > index.html
docker exec nginx-dev cat /usr/share/nginx/html/index.html

# Criar arquivo de dentro do container e ver no host
docker exec nginx-dev sh -c "echo '<p>Criado no container</p>' > /usr/share/nginx/html/novo.html"
ls -la
cat novo.html
```

**Explicação técnica:** O Bind Mount cria uma ligação direta entre um diretório do host e um diretório do container. Qualquer alteração feita no host é imediatamente visível no container e vice-versa, sem necessidade de reiniciar ou reconstruir a imagem. Isso é ideal para desenvolvimento, onde o desenvolvedor precisa ver as mudanças no código refletidas imediatamente na aplicação.

**Diferença entre Bind Mount e Named Volume:**

| Característica | Bind Mount | Named Volume |
|----------------|-----------|--------------|
| Localização | Caminho específico do host | Gerenciado pelo Docker |
| Uso principal | Desenvolvimento | Produção |
| Portabilidade | Baixa | Alta |
| Performance | Média | Alta |

---

### Cenário 4 — Compartilhamento de Dados Entre Containers

**Objetivo:** Validar comunicação e compartilhamento de dados entre containers via volume.

**Comandos utilizados:**

```bash
# Criar volume compartilhado
docker volume create dados-compartilhados

# Container Produtor (escreve dados)
docker run -d \
  --name produtor \
  -v dados-compartilhados:/app/dados \
  alpine \
  sh -c "while true; do echo \"Log gerado em \$(date)\" >> /app/dados/log.txt; sleep 5; done"

# Container Consumidor (lê dados)
docker run -d \
  --name consumidor \
  -v dados-compartilhados:/app/dados \
  alpine \
  sh -c "tail -f /app/dados/log.txt"

# Ver logs do consumidor em tempo real
docker logs consumidor

# Ver arquivo diretamente no volume
docker run --rm \
  -v dados-compartilhados:/dados \
  alpine \
  cat /dados/log.txt
```

**Explicação técnica:** Dois containers independentes montam o mesmo volume em seus sistemas de arquivos internos. O container produtor escreve entradas de log a cada 5 segundos, enquanto o container consumidor lê o arquivo em tempo real. Isso demonstra que volumes Docker funcionam como um sistema de arquivos compartilhado entre containers, sem necessidade de comunicação via rede.

---

### Cenário 5 — Automação de Backup com Script Bash

**Objetivo:** Introduzir automação operacional em infraestrutura com script de backup.

**Script backup.sh:**

```bash
#!/bin/bash
VOLUME_NAME="mysql-prod-data"
CONTAINER_NAME="mysql-funcional"
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$BACKUP_DIR/backup-log.txt"

mkdir -p $BACKUP_DIR

# Backup físico
docker run --rm \
  -v $VOLUME_NAME:/source \
  -v $(pwd)/$BACKUP_DIR:/backup \
  alpine \
  tar czf /backup/volume-backup-$DATE.tar.gz -C /source .

echo "[$(date)] Backup tar concluido!" | tee -a $LOG_FILE

# Backup lógico
if docker ps | grep -q $CONTAINER_NAME; then
  docker exec $CONTAINER_NAME \
    mysqldump -uroot -proot123 --all-databases > $BACKUP_DIR/dump-$DATE.sql
  echo "[$(date)] Dump SQL concluido!" | tee -a $LOG_FILE
fi

# Limpeza de backups antigos
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete

echo "Backup finalizado!"
ls -lh $BACKUP_DIR/
```

**Execução:**

```bash
chmod +x scripts/backup.sh
bash scripts/backup.sh
```

**Explicação técnica:** O script automatiza o processo completo de backup, eliminando a necessidade de intervenção humana. Ele realiza tanto o backup físico (tar.gz do volume) quanto o backup lógico (mysqldump), gera um log de auditoria com timestamps e remove automaticamente backups antigos para economizar espaço em disco.

---

## 4. Evidências

As evidências de cada cenário estão organizadas na pasta `screenshots/`:

- `screenshots/cenario1/` — Criação do volume, container MySQL, inserção de dados e validação da persistência
- `screenshots/cenario2/` — Backup tar.gz, mysqldump, simulação de perda e restauração
- `screenshots/cenario3/` — Bind Mount com Nginx, alterações em tempo real entre host e container
- `screenshots/cenario4/` — Volume compartilhado entre containers produtor e consumidor
- `screenshots/cenario5/` — Scripts de automação e execução do backup

---

## 5. Problemas Encontrados

| Problema | Causa | Solução |
|----------|-------|---------|
| Erro no Bind Mount: `mount path must be absolute` | Faltou `/` no caminho do container | Corrigido para `:/usr/share/nginx/html` |
| `git push` rejeitado | GitHub não aceita senha, exige token | Gerado Personal Access Token com permissão `repo` |
| Pastas vazias não apareciam no GitHub | GitHub não versiona pastas vazias | Adicionado arquivo `.gitkeep` em cada pasta |
| Container MySQL demorava a inicializar | MySQL precisa de tempo para iniciar | Aguardado 15 segundos antes de conectar |

---

## 6. Conclusões

Esta atividade demonstrou na prática a importância da persistência de dados em ambientes containerizados. Os principais aprendizados foram:

- **Containers são efêmeros por natureza** — sem volumes, todos os dados são perdidos ao remover o container
- **Named Volumes** são a solução recomendada para produção, oferecendo alta performance e gerenciamento pelo Docker
- **Bind Mounts** são ideais para desenvolvimento, permitindo que alterações no código sejam refletidas imediatamente no container
- **Backup e restauração** são processos críticos que devem ser automatizados em ambientes reais
- **Volumes compartilhados** permitem comunicação eficiente entre containers sem necessidade de rede
- **Automação via scripts Bash** elimina erros humanos e garante consistência nas operações de infraestrutura

A separação entre o ciclo de vida do container e o ciclo de vida dos dados é um conceito fundamental em DevOps e Cloud Computing, garantindo alta disponibilidade e recuperação de desastres em ambientes de produção.

---

## 7. Estrutura do Repositório

```
infra-persistencia-docker/
├── README.md
├── scripts/
│   ├── backup.sh
│   ├── restore.sh
│   └── mysql-init.sql
├── screenshots/
│   ├── cenario1/
│   ├── cenario2/
│   ├── cenario3/
│   ├── cenario4/
│   └── cenario5/
├── backups/
├── docker/
└── observacoes/
```
