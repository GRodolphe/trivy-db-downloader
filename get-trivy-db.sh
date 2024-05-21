#!/bin/bash

'
.SYNOPSIS
This script downloads the Trivy database without using Docker or Oras as described
in the Trivy documentation for air-gapped environments. See: https://aquasecurity.github.io/trivy/v0.42/docs/advanced/air-gap/#transfer-the-db-files-into-the-air-gapped-environment

.DESCRIPTION
This script queries the GitHub Container Registry API to get access tokens, lists the available tags for the desired Trivy databases (trivy-db and trivy-java-db), allows the user to select a specific tag, and downloads the corresponding database using system or custom proxy settings. This script outputs:
  - manifestFile-trivy-db.json
  - trivy-db.tar.gz
  - manifestFile-trivy-java-db.json
  - manifestFile-trivy-java-db.tar.gz

.REFERENCES
  - https://oras.land/docs/commands/oras_pull/
  - https://aquasecurity.github.io/trivy/v0.42/docs/advanced/air-gap/#transfer-the-db-files-into-the-air-gapped-environment

.NOTES
Version: 0.1
Author: GHIO Rodolphe
If you have any questions, feel free to contact me.
'

# Function to get the bearer token for accessing the repository
get_bearer_token() {
    local repository=$1
    local token_url="https://ghcr.io/token?service=ghcr.io&scope=repository:${repository}:pull&client_id=oras-pull"
    local token_response=$(curl -sL "${token_url}")
    echo "${token_response}" | jq -r '.token'
}

# Function to get a list of available tags in the repository
get_repository_tags() {
    local repository=$1
    local token=$2
    local tags_url="https://ghcr.io/v2/${repository}/tags/list"
    local tags_response=$(curl -sL -H "Authorization: Bearer ${token}" "${tags_url}")
    echo "${tags_response}" | jq -r '.tags[]'
}

# Function to download the manifest and the database
download_database() {
    local repository=$1
    local token=$2
    local tag=$3
    local manifest_url="https://ghcr.io/v2/${repository}/manifests/${tag}"
    local manifest_filename="manifestFile-${repository##*/}.json"
    local db_url
    local db_filename="${repository##*/}.tar.gz"

    # Downloading the manifest
    if ! curl -sL -H "Accept: application/vnd.oci.image.manifest.v1+json" -H "Authorization: Bearer ${token}" -o "${manifest_filename}" "${manifest_url}"; then
        printf >&2 "Error downloading manifest for %s\n" "${repository}"
        return 1
    fi

    local digest=$(jq -r '.layers[].digest' "${manifest_filename}")
    db_url="https://ghcr.io/v2/${repository}/blobs/${digest}"

    # Downloading the database
    printf "Downloading database for %s...\n" "${repository}"
    if ! curl -sL -H "Authorization: Bearer ${token}" -o "${db_filename}" "${db_url}"; then
        printf >&2 "Error downloading database for %s\n" "${repository}"
        return 1
    fi
    printf "Download completed: %s\n" "${db_filename}"
}

main() {
    local repositories=('aquasecurity/trivy-db' 'aquasecurity/trivy-java-db')

    printf "Initialization...\n"

    for repository in "${repositories[@]}"; do
        printf "\n[i] Starting procedure with: %s\n" "${repository}"

        local token
        if ! token=$(get_bearer_token "${repository}"); then
            printf >&2 "Error obtaining bearer token for %s\n" "${repository}"
            continue
        fi

        local tags
        if ! tags=$(get_repository_tags("${repository}" "${token}")); then
            printf >&2 "Error obtaining tags for %s\n" "${repository}"
            continue
        fi

        printf "Available tags for %s: %s\n" "${repository}" "${tags}"
        printf "> Please enter the tag you wish to download: "
        read -r selected_tag

        if [[ -z "${selected_tag}" || ! ${tags} =~ ${selected_tag} ]]; then
            printf >&2 "Error: The specified tag is not available. Please try again.\n"
            continue
        fi

        download_database "${repository}" "${token}" "${selected_tag}"
    done

    printf "\nEnd, closing.\n"
}

main
