#!/bin/bash
set -e
export GOROOT=${GOROOT:-/usr/local/go1.6}
export PATH=$GOROOT/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
export GOPATH=$WORKSPACE

pushd $GOPATH/src/github.com/phrase/phraseapp-client > /dev/null

echo "running go test"
go test ./...

echo "running go vet"
go vet ./...


REVISION=${GIT_COMMIT:-$(git rev-parse HEAD)}
LIBRARY_REVISION=$(cat Godeps/Godeps.json | jq '.Deps[] | select(.ImportPath == "github.com/phrase/phraseapp-go/phraseapp").Rev' -c -r)

if [[ -z $LIBRARY_REVISION ]]; then
  echo "unable to get library revision"
  exit 1
fi

ORIGINAL_VERSION=$VERSION

if [[ -z $VERSION ]]; then
  # try to fetch the most recent version and use <version>-dev
  VERSION=$(git log --pretty=format:'%d' | ruby -e 'puts STDIN.readlines.map { |l| l[/tag: ([\d\.]+)/, 1] }.compact.first')-dev
fi

echo "building version=${VERSION} revision=${REVISION} library_revision=${LIBRARY_REVISION}"

CURRENT_DATE=$(TZ=UTC date +"%Y-%m-%dT%H:%M:%SZ")

DIR=$(mktemp -d /tmp/phraseap-client-XXXX)
trap "rm -Rf $DIR" EXIT

BUILD_SEP="="
if $(go version | grep "go1.4"); then
  BUILD_SEP=" "
fi

function build {
  goos=$1
  goarch=$2
  name=$3
  if [[ -z $name ]]; then
    echo "name must be present"
    exit 1
  fi
  echo "build os=${goos} arch=${goarch} name=$name"
  GOOS=$goos GOARCH=$goarch go build -o $DIR/$name -ldflags "-X main.BUILT_AT${BUILD_SEP}$CURRENT_DATE -X main.REVISION${BUILD_SEP}$REVISION -X main.PHRASEAPP_CLIENT_VERSION${BUILD_SEP}$VERSION -X main.LIBRARY_REVISION${BUILD_SEP}$LIBRARY_REVISION" .
}

build linux   amd64   phraseapp_linux_amd64
build linux   386     phraseapp_linux_386
build darwin  amd64   phraseapp_macosx_amd64
build windows amd64   phraseapp_windows_amd64.exe

pushd $DIR > /dev/null

# Homebrew - binary must be called phraseapp, because the binary name inside
# the tar will be made available system wide
cp phraseapp_macosx_amd64 phraseapp
tar cfz phraseapp_macosx_amd64.tar.gz phraseapp
rm phraseapp

for name in phraseapp_linux_386 phraseapp_linux_amd64; do
  tar cfz ${name}.tar.gz $name
done

zip phraseapp_windows_amd64.exe.zip phraseapp_windows_amd64.exe &> /dev/null
popd

if [[ -n $WORKSPACE ]]; then
  # probably running inside jenkins
  dst=s3://phraseapp-client-releases/${ORIGINAL_VERSION:-$REVISION}/
  aws s3 sync --delete --acl=public-read $DIR $dst
  shasum=$(sha256sum $DIR/phraseapp_macosx_amd64 | awk '{ print $1 }')
  if [[ -z $shasum ]]; then
    echo "unable to get shasum of phraseapp_macosx_amd64"
    exit 1
  fi
  aws s3 cp --acl=public-read $DIR/phraseapp_macosx_amd64 --metadata SHA256=${shasum} $dst/phraseapp_macosx_amd64
fi
