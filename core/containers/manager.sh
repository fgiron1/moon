#!/bin/bash

# core/containers/manager.sh
# Unified container management for OSINT Command Center

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Constants
CONTAINER_DIR="/opt/osint/core/containers"
DATA_DIR="/opt/osint/data"
NETWORK="osint-bridge"
CONTAINERS=(
  "domain"
  "network"
  "identity"
  "web"
  "data"
)

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root${NC}"
  exit 1
fi

# =====================================
# Container Status Functions
# =====================================

# List all containers
list_containers() {
  echo -e "${BLUE}OSINT Tool Containers:${NC}"
  echo -e "${YELLOW}------------------------------${NC}"
  
  # Get running containers
  local running=$(nerdctl ps --format "{{.Names}}")
  
  # Get all containers
  local all=$(nerdctl ps -a --format "{{.Names}}" | grep "osint-")
  
  # Get available container images
  local images=$(nerdctl images --format "{{.Repository}}:{{.Tag}}" | grep "osint-")
  
  # Display running containers
  echo -e "${GREEN}Running Containers:${NC}"
  if [ -z "$running" ]; then
    echo "  No containers running"
  else
    echo "$running" | grep "osint-" | sed 's/^/  /'
  fi
  
  echo
  
  # Display all containers
  echo -e "${GREEN}All Containers:${NC}"
  if [ -z "$all" ]; then
    echo "  No containers found"
  else
    echo "$all" | sed 's/^/  /'
  fi
  
  echo
  
  # Display available images
  echo -e "${GREEN}Available Images:${NC}"
  if [ -z "$images" ]; then
    echo "  No images found"
  else
    echo "$images" | sed 's/^/  /'
  fi
}

# Get container status in JSON format for integration
get_container_status_json() {
  echo '{'
  echo '  "running": ['
  nerdctl ps --format '    {"name": "{{.Names}}", "status": "{{.Status}}", "runtime": "{{.RunningFor}}"},' | grep "osint-" | sed '$ s/,$//'
  echo '  ],'
  echo '  "stopped": ['
  nerdctl ps -a --format '    {"name": "{{.Names}}", "status": "{{.Status}}", "exit_code": "{{.ExitCode}}"},' | grep "osint-" | grep -v "Up " | sed '$ s/,$//'
  echo '  ],'
  echo '  "images": ['
  nerdctl images --format '    {"name": "{{.Repository}}", "tag": "{{.Tag}}", "size": "{{.Size}}"},' | grep "osint-" | sed '$ s/,$//'
  echo '  ]'
  echo '}'
}

# Show detailed info for a container
show_container_info() {
  local container_name="osint-$1"
  
  # Check if container exists
  if ! nerdctl ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
    echo -e "${RED}Container ${container_name} does not exist${NC}"
    return 1
  fi
  
  echo -e "${BLUE}Container Information: ${GREEN}${container_name}${NC}"
  echo -e "${YELLOW}------------------------------${NC}"
  
  # Get container status
  local status=$(nerdctl ps -a --format "{{.Status}}" --filter "name=${container_name}")
  echo -e "${GREEN}Status:${NC} $status"
  
  # Get container details
  echo
  echo -e "${GREEN}Container Details:${NC}"
  nerdctl inspect "${container_name}" | jq -r '.[0] | {
    Image: .Image,
    Command: .Config.Cmd,
    Created: .Created,
    Network: .NetworkSettings.Networks,
    Mounts: .Mounts,
    Ports: .NetworkSettings.Ports
  }'
  
  # Show logs
  echo
  echo -e "${GREEN}Recent Logs:${NC}"
  nerdctl logs --tail 10 "${container_name}" 2>/dev/null || echo "No logs available"
}

# =====================================
# Container Image Management
# =====================================

# Build all containers
build_all() {
  echo -e "${BLUE}Building all OSINT containers...${NC}"
  
  # Build base container first
  echo -e "${YELLOW}Building base container...${NC}"
  nerdctl build -t osint-base:latest $CONTAINER_DIR/base
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build base container${NC}"
    return 1
  fi
  
  # Build tool containers
  for container in "${CONTAINERS[@]}"; do
    # Skip base container
    if [ "$container" == "base" ]; then
      continue
    fi
    
    local container_name="osint-$container"
    echo -e "${YELLOW}Building $container_name...${NC}"
    nerdctl build -t $container_name:latest "$CONTAINER_DIR/$container"
    
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to build $container_name${NC}"
    else
      echo -e "${GREEN}Successfully built $container_name${NC}"
    fi
  done
  
  echo -e "${GREEN}Container build process completed${NC}"
}

# Build a specific container 
build_container() {
  local container=$1
  
  # Validate container name
  if ! [[ " ${CONTAINERS[@]} " =~ " ${container} " ]] && [ "$container" != "base" ]; then
    echo -e "${RED}Invalid container: ${container}${NC}"
    echo -e "Valid containers: base ${CONTAINERS[@]}"
    return 1
  fi
  
  # Build base first if needed
  if [ "$container" != "base" ] && ! nerdctl images | grep -q "osint-base"; then
    echo -e "${YELLOW}Base image not found. Building base container first...${NC}"
    nerdctl build -t osint-base:latest $CONTAINER_DIR/base
    
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to build base container${NC}"
      return 1
    fi
  fi
  
  # Build the specified container
  local container_name=$container
  if [ "$container" != "base" ]; then
    container_name="osint-$container"
  fi
  
  echo -e "${YELLOW}Building ${container_name}...${NC}"
  nerdctl build -t ${container_name}:latest "$CONTAINER_DIR/$container"
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build ${container_name}${NC}"
    return 1
  else
    echo -e "${GREEN}Successfully built ${container_name}${NC}"
    return 0
  fi
}

# Pull pre-built containers
pull_containers() {
  echo -e "${BLUE}Pulling pre-built OSINT containers...${NC}"
  
  # Add registry information here if using a container registry
  local registry="${CONTAINER_REGISTRY:-docker.io/osintcommandcenter}"
  
  # Pull base container first
  echo -e "${YELLOW}Pulling base container...${NC}"
  nerdctl pull $registry/osint-base:latest
  
  # Pull tool containers
  for container in "${CONTAINERS[@]}"; do
    # Skip base container
    if [ "$container" == "base" ]; then
      continue
    fi
    
    local container_name="osint-$container"
    echo -e "${YELLOW}Pulling $container_name...${NC}"
    nerdctl pull $registry/$container_name:latest
    
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to pull $container_name${NC}"
    else
      echo -e "${GREEN}Successfully pulled $container_name${NC}"
    fi
  done
  
  echo -e "${GREEN}Container pull process completed${NC}"
}

# =====================================
# Container Runtime Management
# =====================================

# Start all containers
start_all() {
  echo -e "${BLUE}Starting OSINT tool containers...${NC}"
  
  # Get list of available images
  local images=$(nerdctl images --format "{{.Repository}}" | grep "osint-" | grep -v "osint-base")
  
  if [ -z "$images" ]; then
    echo -e "${RED}No OSINT tool images found. Run 'build' first.${NC}"
    return 1
  fi
  
  # Create a user-defined bridge network if it doesn't exist
  if ! nerdctl network ls | grep -q "$NETWORK"; then
    echo -e "${YELLOW}Creating container network $NETWORK...${NC}"
    nerdctl network create $NETWORK
  fi
  
  # Start each container
  for container in "${CONTAINERS[@]}"; do
    local container_name="osint-$container"
    
    # Skip if image doesn't exist
    if ! nerdctl images | grep -q "$container_name"; then
      echo -e "${YELLOW}Image for $container_name not found, skipping${NC}"
      continue
    fi
    
    # Check if container is already running
    if nerdctl ps | grep -q "$container_name"; then
      echo -e "${YELLOW}Container $container_name is already running${NC}"
      continue
    fi
    
    # Check if container exists but stopped
    if nerdctl ps -a | grep -q "$container_name"; then
      echo -e "${YELLOW}Starting existing container $container_name...${NC}"
      nerdctl start $container_name
      
      if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to start $container_name${NC}"
      else
        echo -e "${GREEN}Successfully started $container_name${NC}"
      fi
      continue
    fi
    
    # Handle container type-specific configurations
    case "$container" in
      data)
        echo -e "${YELLOW}Starting $container_name with data storage configuration...${NC}"
        nerdctl run -d --name $container_name \
          --network $NETWORK \
          -v $DATA_DIR:/opt/osint/data \
          -v $DATA_DIR/neo4j/data:/data \
          -v $DATA_DIR/neo4j/logs:/logs \
          -v $DATA_DIR/neo4j/import:/import \
          -p 7474:7474 -p 7687:7687 \
          $container_name:latest
        ;;
      *)
        echo -e "${YELLOW}Starting $container_name...${NC}"
        nerdctl run -d --name $container_name \
          --network $NETWORK \
          -v $DATA_DIR:/opt/osint/data \
          $container_name:latest sleep infinity
        ;;
    esac
    
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to start $container_name${NC}"
    else
      echo -e "${GREEN}Successfully started $container_name${NC}"
    fi
  done
  
  echo -e "${GREEN}All containers started${NC}"
}

# Start a specific container
start_container() {
  local container=$1
  local container_name="osint-$container"
  
  # Check if container exists
  if ! nerdctl images | grep -q "$container_name"; then
    echo -e "${RED}Image for $container_name not found${NC}"
    return 1
  fi
  
  # Check if container is already running
  if nerdctl ps | grep -q "$container_name"; then
    echo -e "${YELLOW}Container $container_name is already running${NC}"
    return 0
  fi
  
  # Create a user-defined bridge network if it doesn't exist
  if ! nerdctl network ls | grep -q "$NETWORK"; then
    echo -e "${YELLOW}Creating container network $NETWORK...${NC}"
    nerdctl network create $NETWORK
  fi
  
  # Check if container exists but stopped
  if nerdctl ps -a | grep -q "$container_name"; then
    echo -e "${YELLOW}Starting existing container $container_name...${NC}"
    nerdctl start $container_name
    
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to start $container_name${NC}"
      return 1
    else
      echo -e "${GREEN}Successfully started $container_name${NC}"
      return 0
    fi
  fi
  
  # Start container with specific configuration
  case "$container" in
    data)
      echo -e "${YELLOW}Starting $container_name with data storage configuration...${NC}"
      nerdctl run -d --name $container_name \
        --network $NETWORK \
        -v $DATA_DIR:/opt/osint/data \
        -v $DATA_DIR/neo4j/data:/data \
        -v $DATA_DIR/neo4j/logs:/logs \
        -v $DATA_DIR/neo4j/import:/import \
        -p 7474:7474 -p 7687:7687 \
        $container_name:latest
      ;;
    *)
      echo -e "${YELLOW}Starting $container_name...${NC}"
      nerdctl run -d --name $container_name \
        --network $NETWORK \
        -v $DATA_DIR:/opt/osint/data \
        $container_name:latest sleep infinity
      ;;
  esac
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start $container_name${NC}"
    return 1
  else
    echo -e "${GREEN}Successfully started $container_name${NC}"
    return 0
  fi
}

# Stop all containers
stop_all() {
  echo -e "${BLUE}Stopping OSINT tool containers...${NC}"
  
  # Get list of running containers
  local containers=$(nerdctl ps --format "{{.Names}}" | grep "osint-")
  
  if [ -z "$containers" ]; then
    echo -e "${YELLOW}No running containers to stop${NC}"
    return 0
  fi
  
  # Stop each container
  for container in $containers; do
    echo -e "${YELLOW}Stopping $container...${NC}"
    nerdctl stop $container
    
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to stop $container${NC}"
    else
      echo -e "${GREEN}Successfully stopped $container${NC}"
    fi
  done
  
  echo -e "${GREEN}All containers stopped${NC}"
}

# Stop a specific container
stop_container() {
  local container=$1
  local container_name="osint-$container"
  
  # Check if container is running
  if ! nerdctl ps | grep -q "$container_name"; then
    echo -e "${YELLOW}Container $container_name is not running${NC}"
    return 0
  fi
  
  # Stop container
  echo -e "${YELLOW}Stopping $container_name...${NC}"
  nerdctl stop $container_name
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to stop $container_name${NC}"
    return 1
  else
    echo -e "${GREEN}Successfully stopped $container_name${NC}"
    return 0
  fi
}

# Restart all containers
restart_all() {
  echo -e "${BLUE}Restarting OSINT tool containers...${NC}"
  stop_all
  sleep 2
  start_all
}

# Remove all containers
remove_all() {
  echo -e "${BLUE}Removing all OSINT tool containers...${NC}"
  
  # Stop all running containers first
  stop_all
  
  # Remove all containers
  local containers=$(nerdctl ps -a --format "{{.Names}}" | grep "osint-")
  
  if [ -z "$containers" ]; then
    echo -e "${YELLOW}No containers to remove${NC}"
    return 0
  fi
  
  for container in $containers; do
    echo -e "${YELLOW}Removing $container...${NC}"
    nerdctl rm $container
    
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to remove $container${NC}"
    else
      echo -e "${GREEN}Successfully removed $container${NC}"
    fi
  done
  
  echo -e "${GREEN}All containers removed${NC}"
}

# Remove a specific container
remove_container() {
  local container=$1
  local container_name="osint-$container"
  
  # Check if container exists
  if ! nerdctl ps -a | grep -q "$container_name"; then
    echo -e "${YELLOW}Container $container_name does not exist${NC}"
    return 0
  fi
  
  # Stop container if running
  if nerdctl ps | grep -q "$container_name"; then
    echo -e "${YELLOW}Stopping $container_name...${NC}"
    nerdctl stop $container_name
  fi
  
  # Remove container
  echo -e "${YELLOW}Removing $container_name...${NC}"
  nerdctl rm $container_name
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to remove $container_name${NC}"
    return 1
  else
    echo -e "${GREEN}Successfully removed $container_name${NC}"
    return 0
  fi
}

# Update all containers
update_all() {
  echo -e "${BLUE}Updating OSINT tool containers...${NC}"
  
  # Build new containers
  build_all
  
  # Restart with new containers
  restart_all
}

# =====================================
# Container Execution
# =====================================

# Execute command in a container
exec_container() {
  local container=$1
  shift
  local command="$@"
  
  # Format container name
  if ! [[ $container == osint-* ]]; then
    container="osint-$container"
  fi
  
  if [ -z "$container" ]; then
    echo -e "${RED}Error: Container name required${NC}"
    echo -e "Usage: $0 exec CONTAINER [COMMAND]"
    return 1
  fi
  
  if [ -z "$command" ]; then
    command="/bin/bash"
  fi
  
  # Check if container exists
  if ! nerdctl ps -a | grep -q "$container"; then
    echo -e "${RED}Error: Container $container not found${NC}"
    return 1
  fi
  
  # Check if container is running
  if ! nerdctl ps | grep -q "$container"; then
    echo -e "${YELLOW}Container $container is not running. Starting it...${NC}"
    nerdctl start "$container"
  fi
  
  # Execute command
  echo -e "${YELLOW}Executing command in $container...${NC}"
  nerdctl exec -it "$container" $command
}

# Run command in a container
run_tool() {
  local container=$1
  local tool=$2
  shift 2
  local args="$@"
  
  # Format container name
  if ! [[ $container == osint-* ]]; then
    container="osint-$container"
  fi
  
  # Check if container exists
  if ! nerdctl ps -a | grep -q "$container"; then
    echo -e "${RED}Error: Container $container not found${NC}"
    return 1
  fi
  
  # Check if container is running
  if ! nerdctl ps | grep -q "$container"; then
    echo -e "${YELLOW}Container $container is not running. Starting it...${NC}"
    nerdctl start "$container"
    
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to start container ${container}${NC}"
      return 1
    fi
    
    # Wait a moment for container to fully start
    sleep 2
  fi
  
  # Run the tool in the container
  echo -e "${YELLOW}Running $tool in $container...${NC}"
  nerdctl exec -it "$container" $tool $args
}

# =====================================
# Help Function
# =====================================

# Show usage help
show_usage() {
  echo -e "${BLUE}OSINT Container Manager${NC}"
  echo -e "${YELLOW}==================================${NC}"
  echo -e "This script manages the lifecycle of OSINT tool containers."
  echo
  echo -e "${BLUE}Usage:${NC}"
  echo -e "  ${YELLOW}list${NC}                - List all containers and images"
  echo -e "  ${YELLOW}info CONTAINER${NC}      - Show detailed info for a container"
  echo -e "  ${YELLOW}build${NC} [CONTAINER]   - Build all containers or a specific one"
  echo -e "  ${YELLOW}pull${NC}                - Pull pre-built containers from registry"
  echo -e "  ${YELLOW}start${NC} [CONTAINER]   - Start all containers or a specific one"
  echo -e "  ${YELLOW}stop${NC} [CONTAINER]    - Stop all containers or a specific one"
  echo -e "  ${YELLOW}restart${NC}             - Restart all containers"
  echo -e "  ${YELLOW}remove${NC} [CONTAINER]  - Remove all containers or a specific one"
  echo -e "  ${YELLOW}update${NC}              - Update and rebuild all containers"
  echo -e "  ${YELLOW}exec CONTAINER CMD${NC}  - Execute command in container"
  echo -e "  ${YELLOW}run CONTAINER TOOL${NC}  - Run a specific tool in a container"
  echo -e "  ${YELLOW}status-json${NC}         - Output container status in JSON format"
  echo -e "  ${YELLOW}help${NC}                - Show this help message"
  echo
  echo -e "${BLUE}Container Types:${NC}"
  echo -e "  ${YELLOW}domain${NC}     - Domain intelligence container"
  echo -e "  ${YELLOW}network${NC}    - Network scanning container"
  echo -e "  ${YELLOW}identity${NC}   - Identity research container"
  echo -e "  ${YELLOW}web${NC}        - Web analysis container"
  echo -e "  ${YELLOW}data${NC}       - Data storage container"
  echo
  echo -e "${BLUE}Examples:${NC}"
  echo -e "  ${YELLOW}$0 start domain${NC}                    - Start domain container"
  echo -e "  ${YELLOW}$0 exec identity sherlock user123${NC}  - Run sherlock in identity container"
  echo -e "  ${YELLOW}$0 run web nuclei -u example.com${NC}   - Run nuclei in web container"
  echo
}

# =====================================
# Main
# =====================================

main() {
  case "$1" in
    list)
      list_containers
      ;;
    
    info)
      if [ -z "$2" ]; then
        echo -e "${RED}Error: Container name required${NC}"
        echo -e "Usage: $0 info CONTAINER"
        return 1
      fi
      show_container_info "$2"
      ;;
    
    build)
      if [ -z "$2" ]; then
        build_all
      else
        build_container "$2"
      fi
      ;;
    
    pull)
      pull_containers
      ;;
    
    start)
      if [ -z "$2" ]; then
        start_all
      else
        start_container "$2"
      fi
      ;;
    
    stop)
      if [ -z "$2" ]; then
        stop_all
      else
        stop_container "$2"
      fi
      ;;
    
    restart)
      restart_all
      ;;
    
    remove)
      if [ -z "$2" ]; then
        remove_all
      else
        remove_container "$2"
      fi
      ;;
    
    update)
      update_all
      ;;
    
    exec)
      if [ -z "$2" ]; then
        echo -e "${RED}Error: Container name required${NC}"
        echo -e "Usage: $0 exec CONTAINER [COMMAND]"
        return 1
      fi
      exec_container "$2" "${@:3}"
      ;;
    
    run)
      if [ -z "$2" ] || [ -z "$3" ]; then
        echo -e "${RED}Error: Container name and tool required${NC}"
        echo -e "Usage: $0 run CONTAINER TOOL [ARGS...]"
        return 1
      fi
      run_tool "$2" "$3" "${@:4}"
      ;;
    
    status-json)
      get_container_status_json
      ;;
    
    help|--help|-h)
      show_usage
      ;;
    
    *)
      show_usage
      exit 1
      ;;
  esac
}

# Run main function with all arguments
main "$@"