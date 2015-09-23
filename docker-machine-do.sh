#!/bin/sh
set -e
set -x
# Script to setup Docker Swarm with Docker Machine
SWARM_NODES=
API_TOKEN=
#REGISTRY_IP=

#Install Docker
wget -qO- https://get.docker.com/ | sh

#Install Docker-Machine
curl -L https://github.com/docker/machine/releases/download/v0.3.0/docker-machine_linux-amd64 > /usr/local/bin/docker-machine
chmod +x /usr/local/bin/docker-machine

#Install Docker-Compose
curl -L https://github.com/docker/compose/releases/download/1.3.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

#Create Swarm Token
export SWARM_TOKEN=$(docker run swarm create)

#Create Swarm Master
docker-machine --debug create \
  --driver digitalocean \
  --digitalocean-access-token $API_TOKEN \
  --digitalocean-private-networking \
  --swarm \
  --swarm-master \
  --swarm-discovery token://$SWARM_TOKEN \
  swarm-master

#Create Swarm Nodes and configure
for i in $(seq 1 $SWARM_NODES); do
	docker-machine --debug create \
	  --driver digitalocean \
	  --digitalocean-access-token $API_TOKEN \
	  --digitalocean-private-networking \
	  --swarm \
	  --swarm-discovery token://$SWARM_TOKEN \
	  swarm-node-$i
done

