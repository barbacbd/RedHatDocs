#!/bin/bash

if [ "${PWD}" == "/" ]; then
    echo "ERROR: Do not run from the root directory: /"
    exit 1
fi

# the list of expected directories that were created during the configuration
artifact_directories=("root" "usr" "devel")
for dir in "${artifact_directories[@]}"; do
    if [ -d "${dir}" ]; then
	echo "WARNING: Removing all previous data from ${dir}"
	rm -rf ${dir}
    fi
done



