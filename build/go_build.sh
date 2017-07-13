#!/bin/bash
set -e

source $(realpath $(dirname $0))/config.sh
bin_dir=$1

if [[ -z $bin_dir ]]; then
	echo "USAGE: BIN_DIR" > /dev/stderr
	exit 1
fi

function build {
	goos=$1
	goarch=$2
	name=$3
	echo "build os=${goos} arch=${goarch}" > /dev/stderr

	GOOS=$goos GOARCH=$goarch go build -o $bin_dir/${name} -ldflags "-X main.BUILT_AT=$CURRENT_DATE -X=main.REVISION=$REVISION -X=main.PHRASEAPP_CLIENT_VERSION=$VERSION -X=main.LIBRARY_REVISION=$LIBRARY_REVISION" .
}

build linux   amd64   phraseapp_linux_amd64
# build linux   386     phraseapp_linux_386
# build darwin  amd64   phraseapp_macosx_amd64
# build windows amd64   phraseapp_windows_amd64.exe
