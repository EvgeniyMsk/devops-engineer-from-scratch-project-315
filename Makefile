ANSIBLE_DOCKER_TAG ?= latest

galaxy:
	ansible-galaxy install -r requirements.yml

# Secrets are passed via environment variables — never commit them to the repository.
ANSIBLE_SECRET_VARS = \
	-e spring_datasource_username="$(SPRING_DATASOURCE_USERNAME)" \
	-e spring_datasource_password="$(SPRING_DATASOURCE_PASSWORD)" \
	-e storage_s3_accesskey="$(STORAGE_S3_ACCESSKEY)" \
	-e storage_s3_secretkey="$(STORAGE_S3_SECRETKEY)" \
	-e docker_oauth_token="$(DOCKER_OAUTH_TOKEN)"

ifneq ($(strip $(ANSIBLE_PASSWORD)),)
ANSIBLE_SECRET_VARS += -e ansible_password="$(ANSIBLE_PASSWORD)"
endif

define require_deploy_secrets
	@test -n "$(SPRING_DATASOURCE_USERNAME)" || (echo "SPRING_DATASOURCE_USERNAME is not set" && exit 1)
	@test -n "$(SPRING_DATASOURCE_PASSWORD)" || (echo "SPRING_DATASOURCE_PASSWORD is not set" && exit 1)
	@test -n "$(STORAGE_S3_ACCESSKEY)" || (echo "STORAGE_S3_ACCESSKEY is not set" && exit 1)
	@test -n "$(STORAGE_S3_SECRETKEY)" || (echo "STORAGE_S3_SECRETKEY is not set" && exit 1)
	@test -n "$(DOCKER_OAUTH_TOKEN)" || (echo "DOCKER_OAUTH_TOKEN is not set" && exit 1)
endef

setup: galaxy
	$(require_deploy_secrets)
	ansible-playbook playbook.yml $(ANSIBLE_SECRET_VARS)

deploy: galaxy
	$(require_deploy_secrets)
	ansible-playbook playbook.yml -t deploy,certbot,nginx \
		-e docker_tag=$(ANSIBLE_DOCKER_TAG) \
		$(ANSIBLE_SECRET_VARS)

.PHONY: galaxy setup deploy
