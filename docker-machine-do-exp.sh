#!/bin/sh
set -e
set -x
# Script to setup Docker Swarm with Docker Experimental Branch
SWARM_NODES=
API_TOKEN=

#Install Experiemental Docker
wget -qO- https://experimental.docker.com/ | sh

#Install Docker-Machine
curl -L https://github.com/docker/machine/releases/download/v0.3.0/docker-machine_linux-amd64 > /usr/local/bin/docker-machine
chmod +x /usr/local/bin/docker-machine

#Install Docker-Compose
curl -L https://github.com/docker/compose/releases/download/1.3.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

#Create Consul Server
docker-machine --debug create \
    -d digitalocean \
    --digitalocean-access-token $API_TOKEN \
    --digitalocean-private-networking \
    --engine-install-url="https://experimental.docker.com" \
    consul

#Setup Consul Server
docker $(docker-machine config consul) run -d \
    -p "8500:8500" \
    -h "consul" \
    progrium/consul -server -bootstrap

#Create Swarm Token
export SWARM_TOKEN=$(docker run swarm create)

#Create Swarm Master (swarm-0)
docker-machine --debug create \
    -d digitalocean \
    --digitalocean-access-token $API_TOKEN \
    --digitalocean-private-networking \
    --digitalocean-image="ubuntu-14-10-x64" \
    --engine-install-url="https://experimental.docker.com" \
    --engine-opt="kv-store=consul:$(docker-machine ip consul):8500" \
    --engine-label="com.docker.network.driver.overlay.bind_interface=eth0" \
    swarm-0

#Configure Swarm-master
docker $(docker-machine config swarm-0) run -d \
    --restart="always" \
    --net="bridge" \
    swarm:latest join \
        --addr "$(docker-machine ip swarm-0):2376" \
        "token://$SWARM_TOKEN"

docker $(docker-machine config swarm-0) run -d \
    --restart="always" \
    --net="bridge" \
    -p "3376:3376" \
    -v "/etc/docker:/etc/docker" \
    swarm:latest manage \
        --tlsverify \
        --tlscacert="/etc/docker/ca.pem" \
        --tlscert="/etc/docker/server.pem" \
        --tlskey="/etc/docker/server-key.pem" \
        -H "tcp://0.0.0.0:3376" \
        --strategy spread \
        "token://$SWARM_TOKEN"

#Create Swarm Nodes and configure
for i in $(seq 1 $SWARM_NODES); do
	docker-machine --debug create \
	    -d digitalocean \
	    --digitalocean-access-token $API_TOKEN \
        --digitalocean-private-networking \
	    --digitalocean-image="ubuntu-14-10-x64" \
	    --engine-install-url="https://experimental.docker.com" \
	    --engine-opt="kv-store=consul:$(docker-machine ip consul):8500" \
	    --engine-label="com.docker.network.driver.overlay.bind_interface=eth0" \
	    --engine-label="com.docker.network.driver.overlay.neighbor_ip=$(docker-machine ip swarm-0)" \
	    swarm-$i

	docker $(docker-machine config swarm-$i) run -d \
	    --restart="always" \
	    --net="bridge" \
	    swarm:latest join \
	        --addr "$(docker-machine ip swarm-$i):2376" \
	        "token://$SWARM_TOKEN"
done

#Switch to Swarm-master
eval "$(docker-machine env swarm-0)"

#Create Docker-Compose yml
echo '---
HAPROXY:
  image: bfirsh/interlock-haproxy-swarm
  ports:
  - 80:8080
  environment:
  - DOCKER_HOST
  - constraint:node==swarm-0
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

