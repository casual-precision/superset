
REGION := $(AWS_REGION)
ifeq ($(REGION),)
REGION := $(shell aws configure get region)
endif

IMAGE_NAME := $(shell basename $(shell pwd))
ACCOUNT_ID := $(shell aws sts get-caller-identity |  python3 -c "import sys, json; print(json.load(sys.stdin)[\"Account\"])")

REPO_URL := "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/$(IMAGE_NAME)"
TAG := $(shell git log --pretty=format:%h -n 1)
export DOCKER_IMAGE_NAME=$(IMAGE_NAME)

.PHONY: all
all: dev


.PHONY: build
	# Create an admin user in your metadata database
	# superset fab create-admin \
  #                   --username admin \
  #                   --firstname "Admin I."\
  #                   --lastname Strator \
  #                   --email admin@superset.io \
  #                   --password general

build:
	@echo "***Build images***"
	@export DOCKER_IMAGE_NAME=$(IMAGE_NAME)
	docker-compose -f docker-compose-cp.yml build
	docker image prune --force  
	@echo "***Build images completed***"

.PHONY: repo
repo:
	@echo "***Login to ecr***"
	@-aws --region $(REGION) ecr get-login-password | docker login --password-stdin --username AWS $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com || :
	@echo "***Create prod repo***"
	-aws ecr create-repository --repository-name  $(IMAGE_NAME) || :


.PHONY: dev
dev: build push-dev


.PHONY: prod
prod: build push-prod


.PHONY: local
local: build
	

.PHONY: push-dev
push-dev: repo
	@echo "***Tag dev images***"
	docker tag  $(IMAGE_NAME):latest $(REPO_URL):dev-$(TAG)
	docker tag  $(IMAGE_NAME):latest $(REPO_URL):dev-latest
	@echo "***Push dev image***"
	docker push $(REPO_URL):dev-$(TAG)
	docker push $(REPO_URL):dev-latest
	@echo "***Push dev image completed***"


.PHONY: push-prod
push-prod: repo
	@echo "***Tag Prod images***"
	docker tag  $(IMAGE_NAME):latest $(REPO_URL):prod-$(TAG)
	docker tag  $(IMAGE_NAME):latest $(REPO_URL):prod-latest
	@echo "***Push Prod image***"
	docker push $(REPO_URL):prod-$(TAG)
	docker push $(REPO_URL):prod-latest
	@echo "***Push prod image completed***"


.PHONY: run
run: 
	docker-compose -f docker-compose.yml up
	
.PHONY: clean
clean:
	docker system prune -f -a
