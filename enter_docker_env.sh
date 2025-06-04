#!/bin/sh

RELEASE=1.0.1
LOCAL="https://github.com/HateCoriander/docker_build_env/releases/download/local-images-v$RELEASE/luckfox_pico.tar.gz"
TARFILE="$(basename $LOCAL)"

HOSTNAME=luckfoxPico
TIMEOUT=300	# %d seconds
IMAGES="ghcr.io/hatecoriander/luckfox_pico:latest"

TOPDIR=$(dirname $(realpath $0))
SUDOGROUP=$(grep -i sudo $TOPDIR/group.in | cut -d':' -f3)

PASSWD="/etc/passwd"
PASSWDTMP="$TOPDIR/passwd.in"
PASSWDOVERLAY="$TOPDIR/passwd.overlay"

GROUP="/etc/group"
GROUPTMP="$TOPDIR/group.in"
GROUPOVERLAY="$TOPDIR/group.overlay"

SHADOW="/etc/shadow"
SHADOWTMP="$TOPDIR/shadow.in"
SHADOWOVERLAY="$TOPDIR/shadow.overlay"

WORKDIR="$HOME/luckfox"

STATUS=1

if ! which docker > /dev/null 2>&1; then
    echo "Error: Please try again after installed docker!"
    exit $STATUS
fi

if [ ! -f $PASSWDTMP ]; then
    echo "Error: Could not found $PASSWDTMP, please exec 'git pull'"
    exit 1
elif [ ! -f $GROUPTMP ]; then
    echo "Error: Could not found $GROUPTMP, please exec 'git pull'"
    exit 1
elif [ ! -f $SHADOWTMP ]; then
    echo "Error: Could not found $SHADOWTMP, please exec 'git pull'"
    exit 1
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
    docker load -i $TARFILE
    STATUS=$?
    if [ $STATUS -ne 0 ]; then
        echo "Error: Load images failed!"
        exit $STATUS
    fi
fi

echo "Info: Generate the passwd of the overlay"
sed -e "s/<user>/$(id -un)/g" -e "s/<user_id>/$(id -u)/g" $PASSWDTMP > $PASSWDOVERLAY

echo "Info: Generate the group of the overlay"
sed -e "s/<user>/$(id -un)/g" -e "s/<user_id>/$(id -u)/g" $GROUPTMP > $GROUPOVERLAY

echo "Info: Generate the shadow of the overlay"
sed "s/<user>/$(id -un)/g" $SHADOWTMP > $SHADOWOVERLAY

echo "Info: Create the workspace directory"
mkdir -p $WORKDIR

echo -e "Info: Enter container for uid:$(id -u) gid:$(id -g) user:$(id -un)\n"
docker run -ti --rm --user $(id -u):$(id -g) --group-add $SUDOGROUP \
	--hostname $HOSTNAME --workdir $WORKDIR \
	-v $WORKDIR:$WORKDIR \
	-v $PASSWDOVERLAY:$PASSWD:ro \
	-v $GROUPOVERLAY:$GROUP:ro \
	-v $SHADOWOVERLAY:$SHADOW:ro \
	$IMAGES /bin/bash

STATUS=$?
exit $STATUS
