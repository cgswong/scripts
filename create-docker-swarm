#! /usr/bin/env bash
# Create a Docker VM, including Swarm multi-host networked VMs.

# Set values
pkg=${0##*/}

# set colors
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)
reset=$(tput sgr0)

machine-init() {
  # Build test VM if needed
  DOCKER_MACHINE_NAME=${DOCKER_MACHINE_NAME:-"citest"} ; export DOCKER_MACHINE_NAME
  VIRTUALBOX_DISK_SIZE=${VIRTUALBOX_DISK_SIZE:-"10240"}
#  export VIRTUALBOX_BOOT2DOCKER_URL=https://github.com/boot2docker/boot2docker/releases/download/v1.9.0/boot2docker.iso

  docker-machine ls -q | grep "${DOCKER_MACHINE_NAME}" &>/dev/null
  if [ $? -ne 0 ]; then
    if [ ! -z $create_machine ]; then
      echo "${red}Docker host (${DOCKER_MACHINE_NAME}) does not exist and auto-creation disabled. Exiting.${reset}"
      exit 2
    fi
    echo "${yellow}Creating Docker host (${DOCKER_MACHINE_NAME})...${reset}"
    if [ -z $DOCKER_MACHINE_NODES ] || [ $DOCKER_MACHINE_NODES -lt 2 ]; then
      docker-machine create -d virtualbox --virtualbox-disk-size ${VIRTUALBOX_DISK_SIZE} ${DOCKER_MACHINE_NAME}
    else
      # Provision KV-store machine
      echo "${yellow}Creating Docker multi-host kv-store (${DOCKER_MACHINE_NAME}-kvs)...${reset}"
      docker-machine create -d virtualbox ${DOCKER_MACHINE_NAME}-kvs

      # Run distributed key-value store for multi-host networking to work
      echo "${yellow}Running Consul on (${DOCKER_MACHINE_NAME}-kvs)...${reset}"
      docker $(docker-machine config ${DOCKER_MACHINE_NAME}-kvs) run -d -p "8500:8500" -h "consul" --name consul progrium/consul -server -bootstrap

      # Create swarm cluster
      echo "${yellow}Creating Docker Swarm master host (${DOCKER_MACHINE_NAME}-00)...${reset}"
      docker-machine create -d virtualbox \
        --swarm --swarm-master \
        --swarm-discovery="consul://$(docker-machine ip ${DOCKER_MACHINE_NAME}-kvs):8500" \
        --engine-opt="cluster-store=consul://$(docker-machine ip ${DOCKER_MACHINE_NAME}-kvs):8500" \
        --engine-opt="cluster-advertise=eth1:2376" \
        ${DOCKER_MACHINE_NAME}-00

      for ((i=1; i<=${DOCKER_MACHINE_NODES}; i++)); do
        echo "${yellow}Creating Docker Swarm node (${DOCKER_MACHINE_NAME}-${i})...${reset}"
        docker-machine create -d virtualbox \
          --virtualbox-disk-size ${VIRTUALBOX_DISK_SIZE} \
          --swarm \
          --swarm-discovery="consul://$(docker-machine ip ${DOCKER_MACHINE_NAME}-kvs):8500" \
          --engine-opt="cluster-store=consul://$(docker-machine ip ${DOCKER_MACHINE_NAME}-kvs):8500" \
          --engine-opt="cluster-advertise=eth1:2376" \
          ${DOCKER_MACHINE_NAME}-${i}
      done

      eval $(docker-machine env --swarm ${DOCKER_MACHINE_NAME}-00)

      # Create overlay network
      echo "${yellow}Creating Docker multi-host network (mh-net)...${reset}"
      docker network create --driver overlay mh-net
    fi
  else
    docker-machine ls | grep ${DOCKER_MACHINE_NAME} | grep Running &>/dev/null
    if [ $? -ne 0 ]; then
      echo "${green}Starting Docker host (${DOCKER_MACHINE_NAME})...${reset}"
      docker-machine start ${DOCKER_MACHINE_NAME}
    fi
  fi
  eval "$(docker-machine env ${DOCKER_MACHINE_NAME})"
}

usage() {
cat <<EOM

$pkg

Create Docker VM.

Usage: $pkg [OPTIONS]

Options:
  -h,--help               Output help (this message)
  -nc,--no-create         Do not create Docker VM host
  -m=,--machine=[NAME]    Use specified name for Docker VM host (default 'citest')
  -n=,--nodes=[#]        Create specified number of nodes in multi-host configuration.
                          Hosts names will be in the format '[machine name]-#'
  -s=,--size=[MB]         Use specified value in MB for Docker VM HDD (defaults to 10240)

EOM
}

# Process command line
for arg in "$@"; do
  if test -n "$prev_arg"; then
    eval "$prev_arg=\$arg"
    prev_arg=
  fi

  case "$arg" in
      -*=*) optarg=`echo "$arg" | sed 's/[-_a-zA-Z0-9]*=//'` ;;
      *) optarg= ;;
  esac

  case $arg in
    -h | --help)
      usage && exit 0
      ;;
    -nc | --no-create)
      create_machine=0
      ;;
    -m=* | --machine=*)
      DOCKER_MACHINE_NAME="$optarg"
      ;;
    -n=* | --nodes=*)
      DOCKER_MACHINE_NODES="$optarg"
      ;;
    -s=* | --size=*)
      VIRTUALBOX_DISK_SIZE="$optarg"
      ;;
    -*)
      echo "${red}Unknown option $arg, exiting...${reset}" && exit 1
      ;;
    *)
      echo "${red}Unknown option or missing argument for $arg, exiting.${reset}"
      usage
      exit 1
      ;;
  esac
done

machine-init
