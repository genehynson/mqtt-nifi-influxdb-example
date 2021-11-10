build-nifipoc:
	docker build -f ./Dockerfile.nifipoc . -t influxdb/nifipoc:latest

build-nifi:
	docker build -f ./Dockerfile.nifi . -t influxdb/nifi:latest

build:
	$(MAKE) build-nifipoc
	$(MAKE) build-nifi

start:
	docker-compose up -d

stop:
	docker-compose down

logs:
	docker-compose logs -f $(NODE)