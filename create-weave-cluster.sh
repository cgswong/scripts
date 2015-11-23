#!/usr/bin/env bash
# Create a Docker Swarm cluster with Weave networking

# Set values
pkg=${BASH_SOURCE##*/}

# set colors
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)
reset=$(tput sgr0)

# Setup environment
DOCKER_NODE_CNT=${DOCKER_NODE_CNT:-3}
DOCKER_NODE_PREFIX=${DOCKER_NODE_PREFIX:-"weave"}
WEAVE=${WEAVE:-"/usr/local/bin/weave"}

create-machine() {
  # Create the Docker machine VM

  swarm_flags="--swarm --swarm-discovery=token://$(${DOCKER_SWARM_CREATE})"

  for ((i=0; i<${DOCKER_NODE_CNT}; i++)) ; do
    if [ ${i} -eq 0 ]; then
      # Reserve a machine for the Swarm master
      echo "${green}Creating Swarm master ${DOCKER_NODE_PREFIX}-0${reset}"
      docker-machine create --driver virtualbox ${swarm_flags} --swarm-master "${DOCKER_NODE_PREFIX}-0"
    else
      # The actual count is for the Swarm slaves
      echo "${green}Creating Swarm slave ${DOCKER_NODE_PREFIX}-${i}${reset}"
      docker-machine create --driver virtualbox ${swarm_flags} "${DOCKER_NODE_PREFIX}-${i}"
    fi
  done
}

weave-launch() {
  # Setup and launch weave

  for ((i=0; i<${DOCKER_NODE_CNT}; i++)) ; do
    # Environment variable is respected by Weave script, hence it needs to be exported
    export DOCKER_CLIENT_ARGS="$(docker-machine config ${DOCKER_NODE_PREFIX}-${i})"

    # We are going to use IPAM, hence we supply estimated cluster size
    echo "${green}Launching Weave on ${DOCKER_NODE_PREFIX}-${i}${reset}"
    ${WEAVE} launch --init-peer-count ${DOCKER_NODE_CNT}

    # Let's connect-up the Weave cluster by telling each of the nodes about the master/head node
    if [ ${i} -gt 1 ] ; then
      echo "${green}Connecting Weave slave ${DOCKER_NODE_PREFIX}-${i}${reset}"
      ${WEAVE} connect $(docker-machine ip ${DOCKER_NODE_PREFIX}-0)
    fi
  done
}

replace-swarm() {
  # Replace Swarm agent, aside from that, point them to Weave proxy port 12375 instead of Docker port 2376,
  # it will need a new token as the registration on Docker Hub stores an array of `<host>:<port>` pairs
  # and the clean-up method doesn't seem to be documented
  swarm_discovery_token="$(${DOCKER_SWARM_CREATE})"

  for ((i=$((${DOCKER_NODE_CNT}-1)); i>=0; i--)) ; do
    # We are not really using Weave script anymore, so this is only a local variable
    DOCKER_CLIENT_ARGS="$(docker-machine config ${DOCKER_NODE_PREFIX}-${i})"

    ## Default Weave proxy port is 12375
    weave_proxy_endpoint="$(docker-machine ip ${DOCKER_NODE_PREFIX}-${i}):12375"

    ## Next, we restart the slave agents
    echo "${green}Restarting Swarm agent on ${DOCKER_NODE_PREFIX}-${i}${reset}"
    docker ${DOCKER_CLIENT_ARGS} rm -f swarm-agent
    docker ${DOCKER_CLIENT_ARGS} run \
      -d \
      --restart=always \
      --name=swarm-agent \
      swarm join \
      --addr "${weave_proxy_endpoint}" \
      "token://${swarm_discovery_token}"

    if [ ${i} = 0 ] ; then
      # Restart the head/master node with the new token and all the original arguments
      # This is because we need steal all the `--tls*` arguments as well as the `-v` ones
      swarm_master_args_fmt="\
        -d \
        --restart=always \
        --name={{.Name}} \
        -p 3376:3376 \
        {{range .HostConfig.Binds}}-v {{.}} {{end}} \
        swarm{{range .Args}} {{.}}{{end}} \
      "
      swarm_master_args=$(docker ${DOCKER_CLIENT_ARGS} inspect \
          --format="${swarm_master_args_fmt}" \
          swarm-agent-master \
          | sed "s|\(token://\)[[:alnum:]]*|\1${swarm_discovery_token}|")

      echo "${green}Restarting Swarm master agent with new token on ${DOCKER_NODE_PREFIX}-${i}${reset}"
      docker ${DOCKER_CLIENT_ARGS} rm -f swarm-agent-master
      docker ${DOCKER_CLIENT_ARGS} run ${swarm_master_args}
    fi
  done
}

# Use `curl` to create tokens due to ease, otherwise need to either download
# or compile a `docker-swarm` binary or have a Docker daemon running
DOCKER_SWARM_CREATE=${DOCKER_SWARM_CREATE:-"curl -s -XPOST https://discovery-stage.hub.docker.com/v1/clusters"} ; export DOCKER_SWARM_CREATE

# Run main processing
create-machine
weave-launch
replace-swarm
