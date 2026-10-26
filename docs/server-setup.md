# Конфигурация devops-vm

Калугин Никита Александрович, ЭФБО-12-24. Дисциплина «Инструменты девопс».

## 1. Параметры машины

VirtualBox 7.2.22, Ubuntu Server 24.04.5 LTS, 2048 MiB, VDI 25 GiB динамический.
Первоначально выделены 2 vCPU. На данном Windows-хосте VirtualBox использует NEM
(Hyper-V/Core Isolation уже включены). Повторная загрузка с 2 vCPU зависала в initramfs;
для рабочего стенда используется 1 vCPU. Защита Windows не отключалась.
Параметры ядра в /etc/default/grub:
`noapic clocksource=acpi_pm nox2apic rcupdate.rcu_normal=1`.
После изменения — `sudo update-grub`. Снимки делаются при выключенной VM:
live snapshot завис при сохранении памяти под NEM.

## 2. Сетевые интерфейсы

- enp0s3: NAT, DHCP 10.0.2.15/24, шлюз 10.0.2.2, выход в Интернет.
- enp0s8: Host-only, статический 192.168.56.10/24, без шлюза.
- Windows Host-only: 192.168.56.1/24.

`/etc/netplan/60-hostonly.yaml`, права 600:

```yaml
network:
  version: 2
  ethernets:
    enp0s8:
      dhcp4: false
      addresses: [192.168.56.10/24]
      optional: true
```

Первичная конфигурация enp0s3 сохраняется в 50-cloud-init.yaml.
`/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`: `network: {config: disabled}`.
Применение: `sudo netplan apply`; проверка `ip -4 -brief address`, `ip route`.
На Windows в `%SystemRoot%\System32\drivers\etc\hosts`:
`192.168.56.10 devops.local notes.devops.local`.
На VM: hostname `devops-vm.devops.local`; `/etc/hosts` содержит
`127.0.1.1 devops-vm.devops.local devops-vm`.

## 3. Правило проброса портов

NIC1 NAT: имя ssh, TCP 127.0.0.1:2222 → guest:2222.
До hardening гостевой порт был 22. Менять проброс после запуска sshd на 2222,
сохраняя старую сессию до проверки нового входа.

## 4. Учётные записи

student — первоначальная учётная запись установщика, пароль заменён после установки.
devops — отдельная рабочая учётная запись, группы sudo и (с ПР7) docker.
SSH только по выделенному ed25519; `.ssh` 700, `authorized_keys` 600, владелец devops.
Пароль sudo и закрытый ключ не входят в репозиторий.

Клиентский alias:

```sshconfig
Host devops
    HostName 127.0.0.1
    Port 2222
    User devops
    IdentityFile <локальный путь к выделенному ключу>
    IdentitiesOnly yes
    StrictHostKeyChecking yes
```

Fingerprint серверного ключа сверяется через `ssh-keygen -lf
/etc/ssh/ssh_host_ed25519_key.pub`, затем сохраняется в known_hosts клиента.

## 5. Служба SSH

Файл `infra/99-hardening.conf` копируется в `/etc/ssh/sshd_config.d/99-hardening.conf`.
Port 2222; PermitRootLogin no; PasswordAuthentication no;
KbdInteractiveAuthentication no; PubkeyAuthentication yes; PermitEmptyPasswords no;
MaxAuthTries 3; LoginGraceTime 30; AllowUsers devops; X11Forwarding no;
ClientAliveInterval 300; ClientAliveCountMax 2.
В 50-cloud-init.conf удалена конфликтующая PasswordAuthentication:
OpenSSH использует первое найденное значение.

```bash
sudo sshd -t
sudo systemctl disable --now ssh.socket
sudo systemctl enable ssh.service
sudo systemctl restart ssh.service
sudo sshd -T
```

Проверить вторым соединением `ssh devops`, не закрывая первое.

## 6. Правила межсетевого экрана

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2222/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw delete allow 2222/tcp
sudo ufw limit 2222/tcp
sudo ufw logging medium
sudo ufw status verbose
```

С ПР7 учитывать обход UFW INPUT опубликованными Docker-портами.
Порты app и KR2 привязаны только к 127.0.0.1. Базы не публикуют порты.

## 7. Снимки состояния

01-clean-install — установленная и обновлённая Ubuntu до создания devops;
02-keys-configured — devops/sudo и ключи; 03-ssh-hardened — SSH/UFW;
04-nginx-https — сайт и TLS; 05-docker-compose — app/PostgreSQL;
06-before-kr2 — перед КР2; 07-kr2 — итоговый стенд.
После отката на 01 на этом хосте перед запуском задать 1 CPU (снимок хранит исходные 2).
Проброс в 01/02 указывает на guest:22; в 03 и далее на guest:2222.

### Восстановление 01 → 03

1. Выключить VM, восстановить 01, выбрать 1 CPU и NAT host2222→guest22, запустить.
2. Под student: `sudo adduser devops; sudo usermod -aG sudo devops`.
3. Создать `/home/devops/.ssh` 700, перенести открытый ключ в authorized_keys 600,
   назначить владельца devops. Проверить вход `ssh -p 2222 devops@127.0.0.1`.
4. Копировать infra/99-hardening.conf, убрать конфликт PasswordAuthentication из
   50-cloud-init.conf, проверить `sudo sshd -t`, отключить socket и перезапустить ssh.service.
5. Изменить NAT на guest2222, проверить новую сессию; применить команды раздела 6.
6. Задать hostname и /etc/hosts из раздела 2. Проверить `sudo AUDIT_LEVEL=3 scripts/audit.sh`.

## 8. Nginx и HTTPS

Статика `/var/www/devops-site`, владелец devops:devops, каталоги 755, файлы 644.
www-data может читать, но не писать. Конфигурация `infra/devops-site.conf` →
`/etc/nginx/sites-available/devops-site`; симлинк в sites-enabled; default отключён.
После ПР7 включён `/etc/nginx/snippets/devops-app.conf` из infra/app-location.conf.

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt \
  -subj '/CN=devops.local/O=DevOps training' -addext 'subjectAltName=DNS:devops.local'
sudo chmod 600 /etc/ssl/private/devops.key
sudo chmod 644 /etc/ssl/certs/devops.crt
sudo nginx -t && sudo systemctl reload nginx
```

Срок — 365 дней с выпуска; реальные notBefore/notAfter проверяются
`openssl x509 -in /etc/ssl/certs/devops.crt -noout -dates`.
HTTP301→HTTPS, TLS1.2/1.3. HSTS не включён.
Журналы `/var/log/nginx/devops-site.access.log` и `devops-site.error.log`.
Публичный сертификат скопирован в `~/devops.crt` на клиенте для --cacert.
Доставка: `scripts/deploy.sh --dry-run`, затем `scripts/deploy.sh` из чистого Git-дерева.
Для явного пути сертификата: переменная DEPLOY_CA_CERT. Скрипт открывает один SSH
через rsync; итоговый HTTPS проверяет curl на клиенте.

## 9. Docker Compose

Docker Engine установлен из официального apt-репозитория download.docker.com,
пакеты docker-ce/docker-ce-cli/containerd.io/docker-buildx-plugin/docker-compose-plugin.
Доступ к docker group эквивалентен root.
Проект ПР7: `~/app`, app и db, сеть backend, том db_data; app127.0.0.1:5000,
PostgreSQL16-alpine без публикации. Секрет `.env` создаётся на VM, режим 600:
POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD (новый случайный), DB_HOST=db.
`rsync -avz --delete --exclude=.env app/ devops:app/` сохраняет серверный .env.
`docker compose up -d --build --wait`; `docker compose ps/logs`;
`docker compose down` сохраняет том; `down -v` удаляет его данные.
Службы включены в systemd, контейнеры имеют restart unless-stopped.
После ребута проверять readiness и оба HTTPS-ресурса.

## 10. Контрольная работа 2

Номер по списку 10 → вариант2: notes.devops.local, порт8002.
Проект `~/kr2`, app + redis7-alpine, сеть backend, том redis_data, AOF включён.
`.env` содержит новый REDIS_PASSWORD, создаётся один раз и имеет режим600;
он исключён из Git и контекста Docker. Оба сервиса получают один пароль через
интерполяцию Compose; healthcheck использует $$ для раскрытия внутри контейнера.
App публикуется только127.0.0.1:8002; Redis не публикуется.
Отдельный Nginx `/etc/nginx/sites-available/kr2`, симлинк sites-enabled/kr2,
сертификат `/etc/ssl/certs/kr2.crt`, ключ `/etc/ssl/private/kr2.key` root600.
SAN DNS:notes.devops.local, выпуск аналогичен разделу8 с отдельными именами файлов.
`sudo AUDIT_LEVEL=6 scripts/audit.sh` проверяет все этапы, намеренные нарушения возвращают1.
