#!/bin/bash

BUILDBOX_PROMPT="\033[90m$\033[0m"

function buildbox-exit-if-failed {
  if [ $1 -ne 0 ]
  then
    exit $1
  fi
}

function buildbox-run {
  echo -e "$BUILDBOX_PROMPT $1"
  eval $1
  buildbox-exit-if-failed $?
}

echo '--- setting up environment'

# Boot up stuff that isn't by default started in the container
sudo /etc/init.d/postgresql start
sudo /etc/init.d/redis start

# Setup the SSH keys for this agent
echo "$BUILDBOX_AGENT_SSH_PRIVATE_KEY" >> ~/.ssh/id_rsa
echo "$BUILDBOX_AGENT_SSH_PUBLIC_KEY" >> ~/.ssh/id_rsa.pub
chmod 0600 ~/.ssh/id_rsa
chmod 0600 ~/.ssh/id_rsa.pub

# This will return the location of this file. We assume that the buildbox-artifact
# tool is in the same folder. You can of course customize the locations
# and edit this file.
BUILDBOX_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create the build directory
BUILD_DIR="$BUILDBOX_AGENT_NAME/$BUILDBOX_PROJECT_SLUG"

buildbox-run "mkdir -p $BUILD_DIR"
buildbox-run "cd $BUILD_DIR"

# Do we need to do a git checkout?
if [ ! -d ".git" ]; then
  buildbox-run "git clone "$BUILDBOX_REPO" . -qv --depth 20"
fi

echo '--- preparing git'

buildbox-run "git clean -fdq"
buildbox-run "git fetch -q"
buildbox-run "git reset --hard origin/master"
buildbox-run "git checkout -qf \"$BUILDBOX_COMMIT\""

echo "--- running build script"
echo -e "$BUILDBOX_PROMPT ./$BUILDBOX_SCRIPT_PATH"

."/$BUILDBOX_SCRIPT_PATH"
EXIT_STATUS=$?

if [ "$BUILDBOX_ARTIFACT_PATHS" != "" ]
then
  echo "--- uploading artifacts"
  echo -e "$BUILDBOX_PROMPT buildbox-artifact upload \"$BUILDBOX_ARTIFACT_PATHS\""

  $BUILDBOX_DIR/buildbox-artifact upload "$BUILDBOX_ARTIFACT_PATHS" --url $BUILDBOX_AGENT_API_URL
  buildbox-exit-if-failed $?
fi


exit $EXIT_STATUS
