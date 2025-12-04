#!/bin/bash
# This is used to be in setup.sh: install_and_setup_gcloud()
# It was broken and is easier to debug separately

# Bail on any errors
set -e

# Install in $HOME by default, but can set an alternate destination via $1.
ROOT="${ROOT:-$HOME}"

SCRIPT=$(basename $0)
GCLOUD_AUTH_ARGS="${GCLOUD_AUTH_ARGS:---no-launch-browser}"

usage() {
    cat << EOF
usage: $SCRIPT [options]
  --browser    Try to automatically open browser to prompt for credentials.
               (This used to work with the gcloud command but no longer does.
                Suspect some apple security is now blocking things.)
  --root <dir> Use specified directory as root (instead of HOME).
EOF
}

# Process command line arguments
while [[ "$1" != "" ]]; do
    case $1 in
        -b | --browser)
            unset GCLOUD_AUTH_ARGS
            ;;
        -r | --root)
            shift
            ROOT=$1
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
    esac
    shift
done

REPOS_DIR="${REPOS_DIR:-$ROOT/khan}"
DEVTOOLS_DIR="${DEVTOOLS_DIR:-$REPOS_DIR/devtools}"

# This is added to PATh by dotfiles, but those may not be sourced yet.
PATH="$DEVTOOLS_DIR/google-cloud-sdk/bin:$PATH"

echo "$SCRIPT: Using DEVTOOLS_DIR=${DEVTOOLS_DIR}"

version=539.0.0  # should match webapp's MAX_SUPPORTED_VERSION
# This `if` fails if gcloud isn't installed, *or* if it's old.
if ! gcloud version 2>&1 | fgrep -q "$version"; then
    echo "$SCRIPT: Installing Google Cloud SDK (gcloud)"
    # On mac, we could alternately do `brew install google-cloud-sdk`,
    # but we need this code for linux anyway, so we might as well be
    # consistent across platforms; this also makes dotfiles simpler.
    # Also (2021), brew does not supply the version we want on M1.
    arch="$(uname -m)"
    os="$(uname -s)"

    # Handle architecture mapping
    # On macOS ARM (M1/M2), use rosetta (x86_64) for gcloud
    # On Linux ARM (aarch64), gcloud has native ARM builds
    if [ "$os" = "Darwin" ] && [ "$arch" = "arm64" ]; then
        # macOS ARM - use x86_64 via Rosetta
        arch="x86_64"
    elif [ "$arch" = "aarch64" ]; then
        # Linux ARM - use native arm build
        arch="arm"
    fi

    platform="$(echo "$os" | tr ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz)-$arch"
    gcloud_url="https://storage.googleapis.com/cloud-sdk-release/google-cloud-sdk-$version-$platform.tar.gz"
    echo "$SCRIPT: Installing from $gcloud_url"
    local_archive_filename="/tmp/gcloud-$version.tar.gz"
    curl "$gcloud_url" >"$local_archive_filename"
    (
        cd "$DEVTOOLS_DIR"
        rm -rf google-cloud-sdk  # just in case an old one is hanging out
        tar -xzf "$local_archive_filename"
    )
fi

echo "$SCRIPT: Ensuring gcloud is up to date and has the right components."
gcloud components update --quiet --version="$version"
# The components we install:
# - app-engine-java: used by kotlin dev servers
# - app-engine-python: potentially useful for deploying ai-guide-core?
# - bq: biquery tool used by webapp and many humans
# - cloud-datastore-emulator: used by all dev servers (or rather will be
#   "soon" as of March 2019)
# - gsutil: GCS client used by "make current.sqlite" and sometimes humans
# - pubsub-emulator: used in the devserver and for inter-service
#   communication
# - beta: used for the command to start the pubsub emulator
gcloud components install --quiet app-engine-java app-engine-python \
    bq cloud-datastore-emulator gsutil pubsub-emulator beta kubectl

# Turn off checking for updates automatically -- having gcloud always say
# "you can update!" is not useful when we don't want you to!
gcloud config set component_manager/disable_update_check true

# Check authentication after everything is installed
# Need to check both regular auth AND application-default credentials
needs_auth=false
needs_app_default=false

if [ -z "$(gcloud auth list --format='value(account)' 2>/dev/null)" ]; then
    needs_auth=true
fi

# Check if application-default credentials exist
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    needs_app_default=true
fi

if [ "$needs_auth" = true ] || [ "$needs_app_default" = true ]; then
    echo "$SCRIPT: Follow these instructions to authorize gcloud..."

    if [ "$needs_auth" = true ]; then
        echo "$SCRIPT: Step 1: Regular authentication"
        gcloud auth login ${GCLOUD_AUTH_ARGS}
    fi

    if [ "$needs_app_default" = true ]; then
        echo "$SCRIPT: Step 2: Application default credentials"
        gcloud auth application-default login ${GCLOUD_AUTH_ARGS}
    fi
fi

# Always configure Docker authentication (safe to run multiple times)
echo "$SCRIPT: Configuring Docker authentication..."
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet 2>/dev/null || true

echo
echo "$SCRIPT: gcloud ${version} installed and configured!"
