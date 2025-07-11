#!/usr/bin/env bash

####################################################################################################
# Basic Kubernetes Command Aliases
####################################################################################################
alias k='kubectl'
alias ka='kapply'
alias kaf='ka -f'
alias kak='k apply -k'
alias kd='kdesc'
alias kdd='kdesc deployment'
alias kdi='kdesc ingress'
alias kdp='kdesc pod'
alias kds='kdesc service'
alias kg='k get'
alias kl='klogs'
alias klp="klogs pod"
alias krm='k delete'
alias krmf='krm -f'

# Remove the oh-my-zsh kubectl plugin's kge alias
unalias kge 2> /dev/null || true
unalias kgew 2> /dev/null || true

# Resource Retrieval Aliases
# These aliases are for quickly retrieving lists of various Kubernetes resources.
alias kgp='kg pods'
alias kgs='kg services'
alias kgn='kg nodes'
alias kgns='kg namespaces'
alias kgd='kg deployments'
alias kgi='kg ingress'

# Advanced Resource Watching and Listing Aliases
# These aliases add specific options to the get command for more detailed or dynamic listings.
alias kgsvcslwn='kgs --show-labels --watch --namespace' # Get services with labels and watch them in a specified namespace.
alias kgsvcwn='kgs --watch --namespace'                 # Watch services in a specified namespace.
alias kgwf='kg --watch -f'                              # Watch the changes in resources specified in a configuration file.

# Resource Management and Cleanup Aliases
# These aliases facilitate the management and cleanup of Kubernetes resources.
alias krmfinal='remove_finalizers'             # Alias for removing finalizers from resources to unblock deletion.
alias krming='krm ingress'                     # Delete ingresses, straightforward use.
alias krmingall='krm ingress --all-namespaces' # Delete all ingresses across namespaces.
alias krmingl='krm ingress -l'                 # Delete ingresses with specific labels.

####################################################################################################
# Functions
####################################################################################################

# Apply Configuration to Kubernetes Resources
#
# This function streamlines the deployment of configurations to Kubernetes resources using
# the 'kubectl apply' command. It is ideal for developers and operations teams to quickly
# apply changes or deploy resources in a Kubernetes environment. The function supports
# applying configurations from a file, making it convenient for managing Kubernetes
# resources through version-controlled configuration files.
#
# Usage:
#   kapply <file>
#   - <file> is the path to the configuration file that contains the desired state of the resource(s).
#     The file can be in YAML or JSON format and can contain configurations for one or more resources.
#
# Output:
#   Outputs the result of applying the configuration to the resources, including any changes made
#   or errors encountered during the process. If successful, it will indicate that the resources have
#   been configured according to the specified file.
#
# Example(s):
#   kapply deployment.yaml
#   This example applies the configuration specified in deployment.yaml to create or update a deployment.
#   kapply config-map.json
#   This example applies the configuration for a ConfigMap provided in config-map.json.
kapply() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: kapply <file>"
        return 1
    fi

    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Error: File '$file' not found"
        return 1
    fi

    kubectl apply -f "$file"
}

# Retrieve Descriptions of Kubernetes Resources
#
# This function fetches and displays the description of a specified Kubernetes
# resource within a given namespace. If no namespace is specified using the `-n`
# option, the current namespace is used. If no name is specified, it describes
# all resources of the given type in the namespace.
#
# Usage:
#   kdesc [-n <namespace>] <resource> [<name>]
#   - <namespace> is optional. If not specified, the current namespace is used. Specify with `-n`.
#   - <resource> is the type of the Kubernetes resource (e.g., pods, deployments).
#   - <name> is optional. It is the name of the specific resource instance to describe. If not specified, all resources of the given type are described.
#
# Output:
#   Outputs the description of the specified resource. If the resource cannot be found
#   or an error occurs, kubectl will output an error message indicating the problem.
#
# Example(s):
#   This example describes all pods in the current namespace:
#
#   kdesc pods
#
#   This example describes a deployment named external-dns in the networking namespace:
#
#   kdesc -n networking deployments external-dns
#
#   This final example describes all services in the monitoring namespace:
#   kdesc -n monitoring services
kdesc() {
    local namespace
    namespace="$(kubectl config view --minify --output 'jsonpath={..namespace}')"
    local resource
    local name

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n)
                namespace="$2"
                shift 2
                ;;
            *)
                if [[ -z "$resource" ]]; then
                    resource="$1"
                elif [[ -z "$name" ]]; then
                    name="$1"
                else
                    echo "Invalid arguments. Usage: kdesc [-n <namespace>] <resource> [<name>]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$resource" ]]; then
        echo "Usage: kdesc [-n <namespace>] <resource> [<name>]"
        return 1
    fi

    if [[ -n "$name" ]]; then
        kubectl describe -n "${namespace}" "${resource}" "${name}"
    else
        kubectl describe -n "${namespace}" "${resource}"
    fi
}

# Retrieve Events from Kubernetes Clusters
#
# This function fetches and displays events from a specified namespace or from
# all namespaces if 'all' is specified. If no namespace is specified, the current
# namespace is used.
#
# Usage:
#   kge [<namespace>]
#   - <namespace> is optional. If not specified, the current namespace is used.
#     Specify 'all' to retrieve events from all namespaces.
#
# Output:
#   Outputs the events sorted by their creation timestamp. If the namespace cannot be found
#   or an error occurs, kubectl will output an error message indicating the problem.
#
# Example(s):
#   This example retrieves events from the current namespace:
#
#   kge
#
#   This example retrieves events from the kube-system namespace:
#
#   kge kube-system
#
#   This final example retrieves events from all namespaces:
#   kge all
kge() {
    local namespace
    namespace="$(kubectl config view --minify --output 'jsonpath={..namespace}')"
    if [[ -n "$1" && "$1" != "all" ]]; then
        namespace="$1"
    fi

    if [[ "$1" == "all" ]]; then
        kubectl get events --all-namespaces \
            --sort-by='.metadata.creationTimestamp'
    else
        kubectl get events -n "${namespace}" \
            --sort-by='.metadata.creationTimestamp'
    fi
}

# Retrieve Logs from Kubernetes Resources
#
# This function fetches and displays logs for a specified Kubernetes resource
# within a given namespace. If no namespace is specified using the `-n` option,
# the default namespace is used.
#
# Usage:
#   klogs [-n <namespace>] <resource> <name>
#   - <namespace> is optional. If not specified, the current namespace is used. Specify with `-n`.
#   - <resource> is the type of the Kubernetes resource (e.g., pods, deployments).
#   - <name> is the name of the specific resource instance from which to retrieve logs.
#
# Output:
#   Outputs the logs of the specified resource. If the resource cannot be found
#   or an error occurs, kubectl will output an error message indicating the problem.
#
# Example(s):
#   This example retrieves logs from a pod named my-app-pod in the default namespace:
#
#   klogs pod my-app-pod
#
#   This example retrieves logs from a deployment named external-dns in the networking namespace:
#
#   klogs deployments external-dns -n networking
#
#   This final example retrieves logs from a service named grafana in the monitoring namespace:
#   klogs -n monitoring service grafana
klogs() {
    local namespace
    namespace="$(kubectl config view --minify --output 'jsonpath={..namespace}')"
    local resource
    local name

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n)
                namespace="$2"
                shift 2
                ;;
            *)
                if [[ -z "$resource" ]]; then
                    resource="$1"
                elif [[ -z "$name" ]]; then
                    name="$1"
                else
                    echo "Invalid arguments. Usage: klogs [-n <namespace>] <resource> <name>"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$resource" || -z "$name" ]]; then
        echo "Usage: klogs [-n <namespace>] <resource> <name>"
        return 1
    fi

    # Handle resources in the 'apps' group
    if [[ "$resource" == "deployments" ]]; then
        resource="deployments.apps"
    fi

    kubectl logs -n "${namespace}" "${resource}/${name}"
}

# Retrieve Load Balancer IP Addresses in a Kubernetes Namespace
#
# This function fetches and displays the IP addresses of LoadBalancer services
# in a specified namespace or all namespaces if 'all' is specified. If no
# namespace is specified, the current namespace is used.
#
# Usage:
#   kglbip [<namespace>]
#   - <namespace> is optional. If not specified, the current namespace is used.
#     Specify 'all' to retrieve IP addresses from all namespaces.
#
# Output:
#   Outputs the name and IP address of each LoadBalancer service in the format:
#   <service_name>:<ip_address>
#
# Example(s):
#   This example retrieves LoadBalancer IP addresses from the current namespace:
#
#   kglbip
#
#   This example retrieves LoadBalancer IP addresses from all namespaces:
#
#   kglbip all
kglbip() {
    local namespace
    namespace="$(kubectl config view --minify --output 'jsonpath={..namespace}')"
    if [[ -n "$1" && "$1" != "all" ]]; then
        namespace="$1"
    fi

    if [[ "$1" == "all" ]]; then
        kubectl get svc --all-namespaces \
            -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}:{.status.loadBalancer.ingress[0].ip}{"\n"}{end}'
    else
        kubectl get svc -n "${namespace}" \
            -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}:{.status.loadBalancer.ingress[0].ip}{"\n"}{end}'
    fi
}

# Remove Finalizers from Kubernetes Resources
#
# This function patches a specified Kubernetes resource to remove its finalizers,
# allowing it to be deleted if it's stuck in a terminating state. It's useful for
# cleaning up resources that are not being properly cleaned up due to finalizer issues.
#
# Usage:
#   remove_finalizers <resource> <name> <namespace>
#   - <resource> is the type of the Kubernetes resource (e.g., deployments, pods)
#   - <name> is the name of the specific resource instance
#   - <namespace> is the namespace where the resource is located
#
# Output:
#   Outputs a success message if the finalizers were successfully removed.
#   If the operation fails, it outputs a failure message with the resource details.
#
# Example(s):
#   remove_finalizers helmrepositories.source.toolkit.fluxcd.io ingress-traefik flux-system
#   This example removes finalizers from a HelmRepository named ingress-traefik in the flux-system namespace.
remove_finalizers() {
    local resource="$1"
    local name="$2"
    local namespace="$3"

    if [[ -z "$resource" || -z "$name" ]]; then
        echo "Usage: remove_finalizers <resource> <name> [namespace]"
        return 1
    fi

    if [[ "$resource" == "namespace" ]]; then
        if kubectl patch "$resource" "$name" --type json -p '[{"op": "remove", "path": "/metadata/finalizers"}]'; then
            echo "Successfully removed finalizers from $resource $name"
        else
            echo "Failed to remove finalizers from $resource $name"
        fi
    else
        if kubectl patch "$resource" "$name" -n "$namespace" --type json -p '[{"op": "remove", "path": "/metadata/finalizers"}]'; then
            echo "Successfully removed finalizers from $resource $name"
        else
            echo "Failed to remove finalizers from $resource $name"
        fi
    fi
}

# Terminate Pods Stuck in a Terminating State in a Kubernetes Namespace
#
# This function forcefully terminates pods that are stuck in a Terminating state
# in a specified namespace or all namespaces if 'all' is specified. If no namespace
# is specified, the current namespace is used.
#
# Usage:
#   unstick_term_pods [<namespace>]
#   - <namespace> is optional. If not specified, the current namespace is used.
#     Specify 'all' to terminate pods in all namespaces.
#
# Output:
#   Forcefully terminates pods stuck in a Terminating state and outputs the
#   actions taken.
#
# Example(s):
#   This example terminates stuck pods in the current namespace:
#
#   unstick_term_pods
#
#   This example terminates stuck pods in all namespaces:
#
#   unstick_term_pods all
unstick_term_pods() {
    local namespace
    namespace="$(kubectl config view --minify --output 'jsonpath={..namespace}')"
    if [[ -n "$1" && "$1" != "all" ]]; then
        namespace="$1"
    fi

    if [[ "$1" == "all" ]]; then
        kubectl get pods --all-namespaces | grep Terminating | while read -r line; do
            local pod_name
            local ns
            pod_name=$(echo "$line" | awk '{print $2}')
            ns=$(echo "$line" | awk '{print $1}')
            kubectl delete pods "$pod_name" -n "$ns" --grace-period=0 --force
        done
    else
        kubectl get pods -n "${namespace}" | grep Terminating | while read -r line; do
            local pod_name
            pod_name=$(echo "$line" | awk '{print $1}')
            kubectl delete pods "$pod_name" -n "${namespace}" --grace-period=0 --force
        done
    fi
}
