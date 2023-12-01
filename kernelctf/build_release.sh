#!/bin/bash
set -ex

usage() {
    echo "Usage: $0 (lts|cos|mitigation)-<version> [<branch-tag-or-commit>]";
    exit 1;
}

RELEASE_NAME="$1"
BRANCH="$2"

if [[ ! "$RELEASE_NAME" =~ ^(lts|cos|mitigation)-(.*) ]]; then usage; fi
TARGET="${BASH_REMATCH[1]}"
VERSION="${BASH_REMATCH[2]}"

case $TARGET in
  lts)
    REPO="https://github.com/gregkh/linux"
    DEFAULT_BRANCH="v${VERSION}"
    CONFIG_FN="lts.config"
    ;;
  cos)
    REPO="https://cos.googlesource.com/third_party/kernel"
    ;;
  mitigation)
    REPO="https://github.com/thejh/linux"
    case $VERSION in
        v3-6.1.55)
            DEFAULT_BRANCH="mitigations-next"
            CONFIG_FN="mitigation-v3.config"
            CONFIG_FULL_FN="mitigation-v3-full.config"
            ;;
        6.1 | 6.1-v2)
            DEFAULT_BRANCH="slub-virtual-v6.1"
            CONFIG_FN="mitigation-v1.config"
            ;;
    esac ;;
  *)
    usage ;;
esac

BRANCH="${BRANCH:-$DEFAULT_BRANCH}"
if [ -z "$BRANCH" ]; then usage; fi

echo "REPO=$REPO"
echo "BRANCH=$BRANCH"

BASEDIR=`pwd`
BUILD_DIR="$BASEDIR/builds/$RELEASE_NAME"
RELEASE_DIR="$BASEDIR/releases/$RELEASE_NAME"
CONFIGS_DIR="$BASEDIR/kernel_configs"

if [ -d "$RELEASE_DIR" ]; then echo "Release directory already exists. Stopping."; exit 1; fi

mkdir -p $BUILD_DIR 2>/dev/null || true
cd $BUILD_DIR
if [ ! -d ".git" ]; then git init && git remote add origin $REPO; fi

if ! git checkout $BRANCH; then
    git fetch --depth 1 origin $BRANCH:$BRANCH || true # TODO: hack, solve it better
    git checkout $BRANCH
fi

if [ "$TARGET" == "cos" ]; then
    rm lakitu_defconfig || true
    make lakitu_defconfig
    cp .config lakitu_defconfig
else
    curl 'https://cos.googlesource.com/third_party/kernel/+/refs/heads/cos-6.1/arch/x86/configs/lakitu_defconfig?format=text'|base64 -d > lakitu_defconfig
    cp lakitu_defconfig .config
fi

# build everything into the kernel instead of modules
# note: this can increase the attack surface!
sed -i s/=m/=y/g .config

if [ ! -z "$CONFIG_FN" ]; then
    cp $CONFIGS_DIR/$CONFIG_FN kernel/configs/
    make $CONFIG_FN
fi

make olddefconfig

if [ ! -z "$CONFIG_FN" ]; then
    if scripts/diffconfig $CONFIGS_DIR/$CONFIG_FN .config|grep "^[^+]"; then
        echo "Config did not apply cleanly."
        exit 1
    fi
fi

if [ ! -z "$CONFIG_FULL_FN" ]; then
    if scripts/diffconfig $CONFIGS_DIR/$CONFIG_FULL_FN .config|grep "^[^+]"; then
        echo "The full config has differences compared to the applied config. Check if the base config changed since custom config was created."
        exit 1
    fi
fi

make -j`nproc`

mkdir -p $RELEASE_DIR 2>/dev/null || true

echo "REPOSITORY_URL=$REPO" > $RELEASE_DIR/COMMIT_INFO
(echo -n "COMMIT_HASH="; git rev-parse HEAD) >> $RELEASE_DIR/COMMIT_INFO

cp $BUILD_DIR/arch/x86/boot/bzImage $RELEASE_DIR/
cp $BUILD_DIR/lakitu_defconfig $RELEASE_DIR/
cp $BUILD_DIR/.config $RELEASE_DIR/
gzip -c $BUILD_DIR/vmlinux > $RELEASE_DIR/vmlinux.gz
