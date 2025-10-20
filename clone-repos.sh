#!/usr/bin/env bash
set -euo pipefail

script_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspaces_folder="$(cd "${script_folder}/.." && pwd)"

clone-repo()
{
    # Raw input from repos-to-clone.list
    local raw="$1"

    # Sanitize input:
    # - remove Windows CR (\r)
    # - strip inline comments after '#'
    # - drop any query string part after '?'
    # - drop trailing slashes
    # - trim surrounding whitespace
    raw="${raw//$'\r'/}"
    raw="${raw%%#*}"
    raw="${raw%%\?*}"
    raw="${raw%/}"
    local repo_spec
    repo_spec="$(echo -n "$raw" | xargs || true)"

    # Skip empty/comment-only lines after sanitization
    if [ -z "${repo_spec}" ]; then
        echo "Skipping empty/comment line"
        return
    fi

    # Build a canonical clone URL
    local clone_url
    if [[ "${repo_spec}" =~ ^https?:// ]]; then
        clone_url="${repo_spec}"
    else
        clone_url="https://github.com/${repo_spec}"
        case "${clone_url}" in
            *.git) ;;
            *) clone_url="${clone_url}.git" ;;
        esac
    fi

    # Derive a directory name (strip trailing .git if present)
    local repo_dir
    repo_dir="$(basename "${repo_spec}" .git)"

    cd "${workspaces_folder}"
    if [ ! -d "${repo_dir}" ]; then
        echo "Cloning ${clone_url} -> ${repo_dir}"
        git clone "${clone_url}" "${repo_dir}"
    else 
        echo "Already cloned ${repo_spec} (dir ${repo_dir})"
    fi
}

if [ "${CODESPACES:-}" = "true" ]; then
    # Remove the default credential helper
    sudo sed -i -E 's/helper =.*//' /etc/gitconfig

    # Add one that just uses secrets available in the Codespace
    # Prefer GITHUB_TOKEN/GITHUB_ACTOR, fall back to GH_TOKEN/GITHUB_USER
    git config --global credential.helper '!f() { sleep 1; echo "username=${GITHUB_ACTOR:-${GITHUB_USER}}"; echo "password=${GITHUB_TOKEN:-${GH_TOKEN}}"; }; f'
fi

if [ -f "${script_folder}/repos-to-clone.list" ]; then
    # Read all lines, including a final line without a trailing newline
    while IFS= read -r repository || [ -n "$repository" ]; do
        clone-repo "$repository"
    done < "${script_folder}/repos-to-clone.list"
fi
