#!/bin/bash

docker build --file ./.devcontainer/Dockerfile -t kite-tools-devcontainer .
docker run -it --rm --cap-add SYS_PTRACE -v ${PWD}:/home/devel/tools kite-tools-devcontainer /bin/bash