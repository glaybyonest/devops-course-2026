#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"                     # псевдоним из ~/.ssh/config (ПР № 5, шаг 1.6)
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

REPO_ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_ROOT}/site/"
SSH_OPTS="ssh -o BatchMode=yes -o ConnectTimeout=5"

# 1. Разбор аргумента --dry-run
DRY_RUN=0
if [[ $# -gt 0 ]]; then
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        *) echo "Неизвестный аргумент: $1" >&2; exit 1 ;;
    esac
fi

# 4. Проверка наличия главной страницы
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: не найден файл ${LOCAL_DIR}index.html" >&2
    exit 1
fi

# 5. Проверка отсутствия незафиксированных изменений
if [[ -n "$(git -C "${REPO_ROOT}" status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения" >&2
    exit 1
fi

# 3. Синхронизация каталога site/ на сервер
RSYNC_ARGS=(-avz --delete --chmod=D755,F644 -e "${SSH_OPTS}")
if [[ ${DRY_RUN} -eq 1 ]]; then
    rsync "${RSYNC_ARGS[@]}" --dry-run "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"
    echo "Пробный запуск: изменения на сервере не вносились."
    exit 0
fi

rsync "${RSYNC_ARGS[@]}" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# 6. Проверка доступности ресурса с проверкой сертификата
if ! curl -fsS --cacert "${CA_CERT}" -o /dev/null "${SITE_URL}/"; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен или сертификат не прошёл проверку" >&2
    exit 1
fi

# 7. Успешное завершение с коротким хешем доставленного коммита
echo "Доставка выполнена успешно, коммит: $(git -C "${REPO_ROOT}" rev-parse --short HEAD)"