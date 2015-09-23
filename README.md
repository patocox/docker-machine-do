# DockerSwarm on Digigtal Ocean
### Script Instructions 
  1. Create a small 14.04x64 droplet on DigitalOcean to act as your admin box. 
  2. SSH into it and use the contains to create a script called `swarm.sh` and add your API Token for DigitalOcean and how many swarm nodes you would like.
  3. Make it executable: `$ chmod +x swarm.sh`
  4. Run the script! `$ ./swarm.sh`
  5. The script will: Install docker, docker-machine and docker-compose on the admin host; Create a swarm cluster with a swarm master and the number of nodes requested in script

  
### Post-run setup
  1. After script runs, switch to the swarm's daemon: `$ eval "$(docker-machine env --swarm swarm-master)"`
  2. Deploy a docker-compose.yml to it!

