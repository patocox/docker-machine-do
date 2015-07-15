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

#Switch to Swarm-master
eval "$(docker-machine env --swarm swarm-master)"

#Create Docker-Compose yml
echo '---
HAPROXY:
  image: bfirsh/interlock-haproxy-swarm
  ports:
  - 80:8080
  environment:
  - DOCKER_HOST
  - constraint:node==swarm-master
  volumes:
  - /etc/docker:/etc/docker
WP:
  image: centurylink/wordpress:3.9.1
  ports:
  - 8080:80
  links:
  - DB:DB_1
  environment:
  - DB_PASSWORD=pass@word01
  - DB_NAME=wordpress
  - affinity:container!=~WP*
  - affinity:container!=~DB*
  hostname: wordpress.local
DB:
  image: centurylink/mysql:5.5
  ports:
  - 3306:3306
  environment:
  - MYSQL_ROOT_PASSWORD=pass@word01' > docker-compose.yml

# Run docker-compose.yml
docker-compose scale HAPROXY=1 WP=3 DB=1
