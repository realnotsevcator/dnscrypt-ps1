#!/bin/sh

PACKAGE_VERSION="$1"

cd dnscrypt-proxy || exit 1
go clean
env GOOS=windows GOARCH=amd64 go build -mod vendor -ldflags="-s -w"
mkdir win64
mv dnscrypt-proxy.exe win64/
cp ../localhost.pem win64/
