#!/bin/bash

set -e

echo "==> Downloading FFLogs uploader..."

curl -O https://ddosa82diq6o3.cloudfront.net/FFLogsUploader.exe

echo "==> Extracting installer..."

7z x -otmp FFLogsUploader.exe
if [ -f 'tmp/$PLUGINSDIR/app-64.7z' ]; then
  7z x -otmp 'tmp/$PLUGINSDIR/app-64.7z'
fi

echo "==> Downloading asar..."
yarn add asar

echo "==> Unpacking application..."
yarn run asar e tmp/resources/app.asar app

cd app
echo "==> Downloading electron tools..."
yarn add -D electron electron-builder

echo "==> Building linux build..."
yarn run electron-builder -l
cd dist

echo "==> Done! Files are in $(pwd)"