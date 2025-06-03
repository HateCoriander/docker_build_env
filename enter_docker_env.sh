#!/bin/sh

RELEASE=1.0.0
LOCAL="https://github.com/HateCoriander/docker_build_env/releases/download/local-images-v$RELEASE/luckfox_pico.tar"

HOSTNAME=luckfoxPico
TIMEOUT=300	# %d seconds
IMAGES="ghcr.io/hatecoriander/luckfox_pico:latest"
PASSWD="/etc/passwd"
GROUP="/etc/group"

DOCKERID=$(sed -n 's/^docker:[^:]*:\([^:]*\):.*$/\1/p' /etc/group)
TOPDIR=$(dirname $(realpath $0))
SHADOW="/etc/shadow"
SHADOWTMP="$TOPDIR/shadow.in"
SHADOWOVERLAY="$TOPDIR/shadow.overlay"

STATUS=1

if ! which docker > /dev/null 2>&1; then
    echo "Error: Please try again after installed docker!"
    exit $STATUS
fi

echo "Info: Update docker images from $IMAGES ..."
timeout $TIMEOUT docker pull $IMAGES
STATUS=$?
if [ $STATUS -eq 124 ]; then
    echo "Warning: Please check network, docker pull timeout!"
elif [ $STATUS -ne 0 ]; then
    echo "Warning: Please make sure images exist!"
fi

if [ $STATUS -ne 0 ]; then
    echo "Info: Download local images archived file from https"
    wget -P $TOPDIR $LOCAL
    STATUS=$?
    if [ $STATUS -ne 0 ]; then
        echo "Error: Download images failed!"
        exit $STATUS
    fi

    echo "Info: Try to load images to tar"
    docker load -i luckfox_pico.tar
    STATUS=$?
    if [ $STATUS -ne 0 ]; then
        echo "Error: Load images failed!"
        exit $STATUS
    fi
fi

echo "Info: Generate the shadow of the overlay"
sed "s/<user>/$(id -un)/g" $SHADOWTMP > $SHADOWOVERLAY

echo -e "Info: Enter container for uid:$(id -u) gid:$(id -g) user:$(id -un)\n"
docker run -ti --rm --user $(id -u):$(id -g) --group-add $DOCKERID \
	--hostname $HOSTNAME --workdir $HOME \
	-v $HOME:$HOME \
	-v $PASSWD:$PASSWD:ro \
	-v $GROUP:$GROUP:ro \
	-v $SHADOWOVERLAY:$SHADOW:ro \
	$IMAGES /bin/bash

STATUS=$?
exit $STATUS
