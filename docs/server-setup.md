# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

| Параметр | Значение |
|---|---|
| Гипервизор | Oracle VirtualBox 7.2.22 |
| Гостевая ОС | Ubuntu Server 24.04.5 LTS (ядро 6.8.0-147-generic) |
| Оперативная память | 2048 МБ |
| Количество ядер | 1 |
| Диск | 25 ГБ, динамически расширяемый VDI, LVM |

## 2. Сетевые интерфейсы

| Адаптер | Тип | Адрес | Назначение |
|---|---|---|---|
| enp0s3 | NAT | 10.0.2.15/24 | выход в Интернет, обновление пакетов |
| enp0s8 | Host-only | 192.168.56.102/24 | доступ с хостовой системы, веб-сервер |

## 3. Правило проброса портов

| Правило | Протокол | Хост | Гость |
|---|---|---|---|
| ssh | TCP | 127.0.0.1:2222 | 2222 |

## 4. Учётные записи

| Учётная запись | Группы | Аутентификация |
|---|---|---|
| student | student, sudo | пароль |
| devops | devops, sudo, users | ключ ed25519, пароль для sudo |

## 5. Служба SSH

- Порт: 2222.
- Файл конфигурации: `/etc/ssh/sshd_config.d/99-hardening.conf`, эталонная копия основного файла — `/etc/ssh/sshd_config.backup`.
- Директивы: `PermitRootLogin no`, `PasswordAuthentication no`, `PubkeyAuthentication yes`, `PermitEmptyPasswords no`, `MaxAuthTries 3`, `LoginGraceTime 30`, `AllowUsers devops`, `X11Forwarding no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`.
- Запуск: служба `ssh.service`, активация по сокету `ssh.socket` отключена.

## 6. Правила межсетевого экрана

- Политики: `deny (incoming)`, `allow (outgoing)`, routed — disabled.
- Правила: `80/tcp ALLOW` (HTTP), `443/tcp ALLOW` (HTTPS), `2222/tcp LIMIT` (SSH с ограничением частоты).
- Регистрация событий: `ufw logging medium`, журнал `/var/log/ufw.log`.

## 7. Снимки состояния

| Снимок | Момент создания |
|---|---|
| 01-clean-install | после установки ОС и настройки сети |
| 02-keys-configured | после настройки ключевой аутентификации |
| 03-ssh-hardened | после усиления защиты SSH |
| 04-nginx-https | после настройки Nginx и HTTPS |

## 8. Веб-сервер

- Пакет: `nginx` 1.24.0 (Ubuntu).
- Конфигурация ресурса: `/etc/nginx/sites-available/devops-site`, символическая ссылка в `/etc/nginx/sites-enabled/devops-site`, стандартный ресурс `default` отключён.
- Каталог ресурса: `/var/www/devops-site`, владелец `devops:devops`, права 755 для каталогов и 644 для файлов.
- Сертификат: `/etc/ssl/certs/devops.crt` (644, root:root); закрытый ключ: `/etc/ssl/private/devops.key` (600, root:root).
- Команда формирования сертификата:

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key \
  -out /etc/ssl/certs/devops.crt \
  -subj "/CN=devops.local" \
  -addext "subjectAltName=DNS:devops.local"
```

- Срок действия: 365 дней, поле SAN — `DNS:devops.local`.
- Порты: 80 (перенаправление на HTTPS), 443 (HTTPS, TLS 1.2/1.3).
- Журналы: `/var/log/nginx/devops-site.access.log`, `/var/log/nginx/devops-site.error.log`.

## 9. Контейнеризация

- Способ установки Docker Engine: официальный репозиторий `download.docker.com` (ключ в `/etc/apt/keyrings/docker.gpg`), пакеты `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`. Версия Docker Engine — 29.9.3, Docker Compose — v5.7.0. Пакет `docker.io` не использовался.
- Участники группы `docker`: учётная запись `devops`.
- Расположение проекта на сервере: `/home/devops/app` (`Dockerfile`, `app.py`, `requirements.txt`, `docker-compose.yml`, `.env`).
- Файл `.env`: `/home/devops/app/.env`, владелец `devops`, права 600; в репозиторий не входит, шаблон — `app/.env.example`.
- Публикуемые порты и адреса: приложение — `127.0.0.1:5000` (только петлевой интерфейс); порт СУБД 5432 не публикуется.
- Именованные тома: `app_db_data` — данные PostgreSQL, сохраняются при `docker compose down` и удаляются при `docker compose down -v`.
- Конфигурация обратного прокси-сервера: в блоке HTTPS файла `/etc/nginx/sites-available/devops-site` добавлено расположение `location /app/` с `proxy_pass http://127.0.0.1:5000/` и заголовками `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`.
- Снимок состояния: `05-docker-compose`.