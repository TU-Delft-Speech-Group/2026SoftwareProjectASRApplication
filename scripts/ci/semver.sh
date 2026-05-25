#!/bin/bash
set -euo pipefail

# Uses GitLab CI predefined variables to determine the type of version bump.
# GitLab CI variables: https://docs.gitlab.com/ci/variables/predefined_variables/

print_usage() {
  echo "Semantic Versioning Script for GitLab CI."
  echo "Expects to be run on the main branch or a merge request to main. Will determine the type of version bump based on the commit message using Conventional Commits format."
  echo "On hotfix it performs a patch bump, otherwise it performs a minor bump. Major bumps should be done manually."
  echo ""
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -d, --dry-run   Run without making any changes."
  echo "  -s, --silent    Only print the new version number."
  echo "  -h, --help      Display this help message."
  echo ""
  echo "This script requires the following environment variables to be set:"
  echo " CI_COMMIT_BRANCH CI_COMMIT_TITLE (CI_COMMIT_BRANCH or CI_MERGE_REQUEST_TARGET_BRANCH_NAME==main)"
  echo "The script should not be run on a tagged commit (CI_COMMIT_TAG should be empty)."
}

# verify_environment - checks that the environment variables are set correctly and necessary files are present.
# 
# Arguments:
#   $1 - path to pubspec.yaml (must be present)
#
# Variables checked:
#   CI_COMMIT_TAG (must not be set)
#   CI_COMMIT_TITLE (must be set)
#   CI_COMMIT_BRANCH (must be set to "main") or CI_MERGE_REQUEST_TARGET_BRANCH_NAME (must be set to "main")
verify_environment() {
  local pubspec_file="$1"

  if [[ -n "${CI_COMMIT_TAG:-}" ]]; then
    echo "Error: This script should not be run on a tagged commit." >&2
    exit 1
  fi

  if [[ -z "${CI_COMMIT_TITLE:-}" ]]; then
    echo "Error: CI_COMMIT_TITLE is not set." >&2
    exit 1
  fi

  if [[ ! -f "$pubspec_file" ]]; then
    echo "Error: $pubspec_file not found." >&2
    exit 1
  fi

  if [ "${CI_COMMIT_BRANCH:-}" == "main" ]; then
    return
  elif [ "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-}" == "main" ]; then
    return
  else
    echo "Error: This script should only be run on a commit on main or a merge request to main." >&2
    exit 1
  fi
}

semver() {
  local pubspec_file="pubspec.yaml"

  local DRY_RUN=0
  local SILENT=0

  local POSITIONAL_ARGS=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -d|--dry-run)
        DRY_RUN=1
        shift # past argument
        ;;
      -s|--silent)
        SILENT=1
        shift # past argument
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      -*|--*)
        echo "Unknown option $1" >&2
        exit 1
        ;;
      *)
        POSITIONAL_ARGS+=("$1") # save positional arg
        shift # past argument
        ;;
    esac
  done

  verify_environment "$pubspec_file"

  local env
  if [[ -z "${CI_COMMIT_BRANCH:-}" ]]; then
    [ $SILENT -eq 0 ] && echo "Running in merge request environment, automatic dry-run."
    DRY_RUN=1
  fi

  local current_version=$(grep -m 1 -Ee "^version: [[:digit:]]+.[[:digit:]]+.[[:digit:]]+\+[[:digit:]]+$" "$pubspec_file" | sed -e 's/version: //')
  [ $SILENT -eq 0 ] && echo "Current version: ${current_version}"

  local new_version
  if [[ "$CI_COMMIT_TITLE" == hotfix* ]]; then
    new_version=$(echo "$current_version" | awk -F[.+] '{print $1 "." $2 "." $3+1 "+" $4+1}')
    [ $SILENT -eq 0 ] && echo "Hotfix, performing patch bump: ${new_version}"
  else
    new_version=$(echo "$current_version" | awk -F[.+] '{print $1 "." $2+1 "." 0 "+" $4+1}')
    [ $SILENT -eq 0 ] && echo "Performing minor bump: ${new_version}"
  fi

  if [ $DRY_RUN -eq 0 ]; then
    [ $SILENT -eq 0 ] && echo "Patching pubspec version"
    sed -i "s/version: ${current_version}/version: ${new_version}/" "$pubspec_file"
  else
    [ $SILENT -eq 0 ] && echo "Dry run, not modifying pubspec version"
  fi

  echo "New version: ${new_version}"
}

semver "$@"