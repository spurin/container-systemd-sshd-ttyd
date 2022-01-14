## ✨ Popular linux distributions configured with systemd, ttyd and sshd (centos_8) ✨

Popular linux distributions with systemd, ttyd and sshd.  Superb for use with Docker 🐋

## Overview

Configured with /usr/bin/login to present itself in a fashion similar to a virtual machine.  Terminal access via Web (ttyd) and/or SSH.  Users can be configured through file entries in the /config directory.  See base examples and customise with a volume mount for your own needs.  Without customisation, login credentials are guest/guest and root/root

The image relating to this Dockerfile is available for both amd64 and arm64 on Docker Hub - ```spurin/container-systemd-sshd-ttyd:centos_8```

## Example

Run a container and expose ttyd (on port 7681) and sshd (on port 2222) -

```
CONTAINER=$(docker run -p 7681:7681 -p 2222:22 -d --privileged spurin/container-systemd-sshd-ttyd:centos_8)
docker exec -it $CONTAINER bash
```

Terminate and Remove -

```
docker stop $CONTAINER
docker rm $CONTAINER
```

## Build

See the build.sh script for 3 options that can be used for build purposes

1. Build locally
2. Crossbuild with buildx for amd64 and arm64 (Slow!)
3. Crossbuild with buildx for amd64 and arm64 using a dedicated instance for alternative cross building (configure accordingly for your remote architecture)
