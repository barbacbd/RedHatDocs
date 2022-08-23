#!/bin/bash

if [ -f "ci-pull-secret.json" ] ; then
    echo "[DEBUG] CI Pull Secret exists, making a copy ...";
    mv ci-pull-secret.json ci-pull-secret.json_copy;
fi

echo "[INFO] Pull latest CI Pull secret into ci-pull-secret.json";
oc registry login --to ci-pull-secret.json

if [ -f "ci-pull-secret.json_copy" ] ; then
    # compare to see if there was a difference in files
    if cmp --silent -- "ci-pull-secret.json" "ci-pull-secret.json_copy"; then
	echo "[WARNING] There has been an update to your key ...";
    fi

    rm "ci-pull-secret.json_copy";
fi

if [ ! -f "all-pull-secrets.txt" ] ; then
    echo "[ERROR] File all-pull-secrets.txt does NOT exist, please pull online.";
    exit;
fi

echo "[INFO] Combining file contents into pull-secrets.txt ..."
jq -c -s '.[0] * .[1]' ci-pull-secret.json all-pull-secrets.txt > pull-secrets.txt

echo "[DEBUG] Copying pull-secrets.txt to ~/.docker/config.json";
cp pull-secrets.txt ~/.docker/config.json
echo "[DEBUG] Copying pull-secrets.txt to ~/";
cp pull-secrets.txt ~/
echo "[DEBUG] Copying pull-secrets.txt to ~/oi/pull-secret.json";
cp pull-secrets.txt ~/oi/pull-secret.json
