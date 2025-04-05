#!/usr/bin/env bash

# Fix zshrc autocomplete with exec
# https://github.com/moby/moby/issues/31216#issuecomment-281397184
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

# Docker utilities
alias cleanseDocker='docker system prune -f -a'
alias createDataContainer="docker create -v /tmp --name datacontainer ubuntu"
alias updateDockerImages="docker images | \
    cut -d ' ' -f 1 | xargs -I {} docker pull {} 2>&1"
alias docker_ports='docker container ls --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}" -a'
# Run docker ps indefinitely every 30 seconds.
alias inf-docker-ps='while true; do docker ps; sleep 30; done'

# Programming languages
alias python2.7.16="docker run -it --rm --name=python2.7.16 python:2.7.16"
alias python3.7.3="docker run -it --rm --name=python3.7.3 python:3.7.3"

# Operating Systems
alias ubuntu="docker run -it --rm --name=ubuntu ubuntu"
alias debian="docker run -it --rm --name=debian debian"
alias stretch="docker run -it --rm --name=stretch debian:stretch"
alias centos="docker run -it --rm --name=centos centos"

# Security tools
# This can be used if we don't want to persist:
alias kali='docker run --rm -it -v $HOME/.kali/root:/root \
    -v $HOME/.kali/postgres:/var/lib/postgresql \
    -p 4444:4444 --name=kali kalilinux/kali-last-release'
alias sqlmap='docker run --rm -it -v $HOME/.sqlmap:/home/user/.sqlmap \
    k0st/alpine-sqlmap'
alias beef="docker run -d -p 3000:3000 --name=beef fcolista/alpine-beef"
alias oxml_xxe="docker run -p 4567:4567 -it --name=oxml_xxe devalias/oxml_xxe"
# Use dictionaries from Seclists if installed
#if [ -d "$HOME/SecLists" ]; then
#  alias wpscan="docker run --rm -v $HOME/SecLists/Passwords:/passwords wpscanteam/wpscan"
#else
alias wpscan="docker run --rm wpscanteam/wpscan"
#fi

# Vulnerable Containers
alias bricks="docker run --rm -d -p 80:80 --name=bricks citizenstig/owaspbricks"
alias bwapp="docker run --rm -d -p 86:80 --name=bwapp raesene/bwapp && \
    echo 'Go to /install.php to configure'"
alias dvwa="docker run --rm -d -p 85:80 --name=dvwa citizenstig/dvwa"
alias gruyere="docker run -d -p 8008:8008 karthequian/gruyere"
alias juice-shop="docker run --rm -d -p 3005:3000 --name=juice bkimminich/juice-shop"
alias nowasp="docker run --rm -d -p 86:80 -p 3306:3306 \
    -e MYSQL_PASS="Chang3ME!" --name=mutillidae citizenstig/nowasp"
alias vulnwp="docker run --rm -d -p 80:80 -p 3306:3306 \
    --name=vulnwp wpscanteam/vulnerablewordpress"
alias shellshock="docker run -d -p 8080:80 hmlio/vaas-cve-2014-6271"
alias webgoat7="docker run --rm -d -p 8086:8080 --name=webgoat7 webgoat/webgoat-7.1"
alias webgoat8="docker run --rm -d -p 8085:8080 --name=webgoat8 -t webgoat/webgoat-8.0"

# Miscellaneous containers
alias jenkins="docker run -d --rm -p 8080:8080 -p 50000:50000 --name jenkins jenkins"
alias redis="docker run -d --rm -p 6379:6379 --name redis redis"
alias plone="docker run -d --rm -p 8080:8080 --name plone plone"
alias coldfusion2016="docker run --rm -d --name mycf2016 \
    -p 80:80 -p 8500:8500 accent/coldfusion2016"
alias laverna="docker run --rm -d -p 5000:80 --name laverna elliotjreed/laverna"
alias postgres="docker run --rm -d --name postgres postgres"
alias ghost="docker run --rm -d -p 2368:2368 --name ghost ghost"

# List all Docker containers with their mount points.
list_docker_mounts() {
    # Get all container IDs
    local container_ids
    container_ids=$(docker ps -a --format '{{ .ID }}')

    if [ -z "$container_ids" ]; then
        echo "No containers found"
        return 0
    fi

    echo "Listing all containers with their mount points:"
    echo "----------------------------------------------"

    # Iterate through each container and display its mounts
    for container_id in $container_ids; do
        docker inspect -f '{{ .Name }}{{ printf "\n" }}{{ range .Mounts }}{{ printf "\n\t" }}{{ .Type }} {{ if eq .Type "bind" }}{{ .Source }}{{ end }}{{ .Name }} => {{ .Destination }}{{ end }}{{ printf "\n" }}' "$container_id"
    done
}

# List mount points for a specific container.
# Usage: list_container_mounts container_name_or_id
list_container_mounts() {
    local container="$1"

    if [ -z "$container" ]; then
        echo "Error: Container name or ID not provided"
        echo "Usage: list_container_mounts container_name_or_id"
        return 1
    fi

    if ! docker inspect "$container" > /dev/null 2>&1; then
        echo "Error: Container '$container' not found"
        return 1
    fi

    echo "Listing mount points for container '$container':"
    echo "------------------------------------------------------"
    docker inspect -f '{{ .Name }}{{ printf "\n" }}{{ range .Mounts }}{{ printf "\n\t" }}{{ .Type }} {{ if eq .Type "bind" }}{{ .Source }}{{ end }}{{ .Name }} => {{ .Destination }}{{ end }}{{ printf "\n" }}' "$container"
}
