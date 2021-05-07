SHELL=/bin/bash
VENVDIR?=${HOME}/.virtualenvs
WORKDIR?=$(shell basename "$$PWD")
VENV?=$(VENVDIR)/$(WORKDIR)/bin
PYTHON?=$(VENV)/python
ACTIVATE?=$(VENV)/activate

create-virtual-env:
	mkdir -p ~/.virtualenvs && \
	python3 -m venv $(VENVDIR)/$(WORKDIR) && \
	. $(ACTIVATE) && \
	pip install --upgrade pip setuptools && \
	pip install -r requirements-dev.txt

# USAGE: make create-doppler-project GIPHY_API_KEY=XXXX
create-doppler-project:
	@echo '[info]: Creating "mandalorion-gifs" project'
	@doppler projects create mandalorion-gifs
	@doppler setup --no-prompt

	@echo '[info]: Uploading default secrets'
	@doppler secrets upload --config dev sample.env
	@doppler secrets upload --config prd sample.env	

	@echo '[info]: Randomizing Flask secret key'
	@doppler secrets set --config dev SECRET_KEY "$(shell python -c 'import uuid; print(uuid.uuid4())')"
	@doppler secrets set --config prd SECRET_KEY "$(shell python -c 'import uuid; print(uuid.uuid4())')"

	@echo '[info]: Adjusting production values'	
	@doppler secrets delete --config stg FLASK_DEBUG FLASK_ENV GIPHY_API_KEY GIPHY_RATING GIPHY_TAG HOST PORT SECRET_KEY -y
	@doppler secrets delete --config prd FLASK_DEBUG FLASK_ENV PORT -y
	@doppler secrets set --config prd HOST "0.0.0.0"

	@echo '[info]: Setting GIPHY API KEY'
	@doppler secrets set GIPHY_API_KEY="$(GIPHY_API_KEY)"
	@doppler secrets set --config prd GIPHY_API_KEY="$(GIPHY_API_KEY)"

	@echo '[info]: Opening the Doppler dashboard'
	@doppler open dashboard

dev:
	doppler run -- $(PYTHON) src/app.py

lint:
	. $(ACTIVATE) && flake8 --ignore E501 src

gunicorn:
	. $(ACTIVATE) && doppler run -- gunicorn --pythonpath src app:app

devcontainer-doppler-token:
	@echo "DOPPLER_TOKEN=$(shell doppler configure get token --plain)" > .devcontainer/.env
	@echo "DOPPLER_PROJECT=$(shell doppler configure get project --plain)" >> .devcontainer/.env
	@echo "DOPPLER_CONFIG=$(shell doppler configure get config --plain)" >> .devcontainer/.env


############
#  Docker  #
############

CONTAINER_NAME=mandalorion-gifs
IMAGE_NAME=dopplerhq/mandalorion-gifs

docker-build:
	docker image pull python:alpine
	docker image build -t $(IMAGE_NAME):latest .

docker:
	# Runs as root user in order to install dev packages
	docker container run \
		-it \
		--init \
		--rm \
		--name mandalorion-gifs \
		-v $(shell pwd):/usr/src/app:cached \
		-u root \
		-p $(shell doppler secrets get PORT --plain):$(shell doppler secrets get PORT --plain) \
		--env-file <(doppler secrets download --no-file --format docker) \
		$(IMAGE_NAME)


############
#  HEROKU  #
############

HEROKU_TEAM=dopplerhq
HEROKU_APP=mandalorion-gifs

heroku-create:
	heroku apps:create --team $(HEROKU_TEAM) $(HEROKU_APP)
	git remote rename heroku $(HEROKU_APP)
	$(MAKE) heroku-deploy HEROKU_APP=$(HEROKU_APP)

heroku-deploy:
	git push $(HEROKU_APP) master -f
	heroku open --app $(HEROKU_APP)

heroku-destroy:
	heroku apps:destroy --app $(HEROKU_APP) --confirm $(HEROKU_APP)
