# DevOps Engineer — Ansible Deployment

[![Hexlet check](https://github.com/EvgeniyMsk/devops-engineer-from-scratch-project-315/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/EvgeniyMsk/devops-engineer-from-scratch-project-315/actions)

**Production:** [https://task.devops-campus.ru](https://task.devops-campus.ru)

Ansible-плейбуки для развёртывания [project-devops-deploy](https://github.com/EvgeniyMsk/project-devops-deploy) на сервере Yandex Cloud.

В этом репозитории — **только инфраструктура и деплой** (Ansible). Код приложения, `Dockerfile` и CI для сборки образа — в форке приложения.

## Архитектура

```text
Internet
   │
   ▼
Nginx (:80 / :443)          task.devops-campus.ru
   │  static: /var/www/bulletins
   │  proxy: 127.0.0.1:8080
   ▼
application (Docker)        Spring Boot, prod profile
   │  logs: /var/log/bulletins
   ▼
database (postgres:14)      PostgreSQL, data: /var/lib/postgresql/bulletins
   │
   ▼
Yandex Object Storage       bulletin images (S3-compatible)
```

| Компонент | Детали |
|-----------|--------|
| Docker-образ | `cr.yandex/crpragsrepkuej79fefp/project-devops-deploy` (собирается CI в репозитории приложения) |
| База данных | `postgres:14`, volume `/var/lib/postgresql/bulletins` |
| Reverse proxy | Nginx + TLS (Certbot / Let's Encrypt) |
| Домен | `task.devops-campus.ru` → A-запись на IP сервера |

## Требования

**Control node** (локальная машина или CI):

- Python 3.12+, Ansible (`pip install ansible`)
- SSH-доступ к серверу (ключ или пароль через переменную окружения)
- Переменные окружения с секретами (см. ниже)

**Target server** (Ubuntu 22.04+):

- Публичные порты 80 и 443
- Порты 8080/9090 привязаны к `127.0.0.1`
- DNS A-запись для `task.devops-campus.ru`

## Структура

| Файл / каталог | Назначение |
|----------------|------------|
| `playbook.yml` | Главный плейбук |
| `inventory/inventory.ini` | Хост и SSH-настройки |
| `inventory/group_vars/web_servers.yml` | Публичные переменные (домен, образ, S3 bucket) |
| `requirements.yml` | Ansible-роли и коллекции |
| `tasks/` | Задачи: firewall, nginx, certbot, deploy |
| `templates/` | Шаблоны конфигурации Nginx |

## Секреты

Не храните пароли и ключи в репозитории. Передавайте их через переменные окружения:

| Переменная окружения | Ansible-переменная |
|---------------------|-------------------|
| `SPRING_DATASOURCE_USERNAME` | `spring_datasource_username` |
| `SPRING_DATASOURCE_PASSWORD` | `spring_datasource_password` |
| `STORAGE_S3_ACCESSKEY` | `storage_s3_accesskey` |
| `STORAGE_S3_SECRETKEY` | `storage_s3_secretkey` |
| `DOCKER_OAUTH_TOKEN` | `docker_oauth_token` |
| `ANSIBLE_PASSWORD` | `ansible_password` (SSH, опционально) |

## Команды

```bash
# Установить Ansible-роли (один раз или перед каждым запуском)
make galaxy

# Первичная настройка сервера (Docker, UFW, Nginx, Certbot, PostgreSQL, приложение)
export SPRING_DATASOURCE_USERNAME=...
export SPRING_DATASOURCE_PASSWORD=...
export STORAGE_S3_ACCESSKEY=...
export STORAGE_S3_SECRETKEY=...
export DOCKER_OAUTH_TOKEN=...
make setup

# Обновление приложения (pull образа, пересоздание контейнеров, Nginx, Certbot)
make deploy

# Откат на конкретную сборку (git SHA из CI репозитория приложения)
make deploy ANSIBLE_DOCKER_TAG=<git-sha>
```

`make deploy` запускает теги `deploy,certbot,nginx`.

## Обновление образа

CI в [project-devops-deploy](https://github.com/EvgeniyMsk/project-devops-deploy) публикует теги `latest` и `<git-sha>` в Yandex Container Registry. При `make deploy` Ansible:

1. Логинится в registry.
2. Скачивает `{{ docker_image }}:{{ docker_tag }}`.
3. Пересоздаёт контейнеры `application` и `database`.
4. Извлекает frontend static из JAR в `/var/www/bulletins`.

Тег образа задаётся в `inventory/group_vars/web_servers.yml` (`docker_tag`, по умолчанию `latest`) или через `ANSIBLE_DOCKER_TAG`.

## Проверка production

```bash
# На сервере
docker ps
docker logs application --tail 30
curl -s http://127.0.0.1:8080/api/bulletins
curl -I https://task.devops-campus.ru
```
