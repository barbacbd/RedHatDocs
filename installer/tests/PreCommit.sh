#!/bin/bash
##########################################################
# This script is meant to be run executed before         #
# committing any code/PR for the installer project.      #
# All scripts referenced exist in the installer project. #
##########################################################

set -eux

hack/go-fmt.sh -d .

# Note: Go-lint is skipped as it is failing because it
# does not currently exist.
#hack/go-lint.sh $(go list -f '{{ .ImportPath }}' ./...)

hack/shellcheck.sh
hack/tf-fmt.sh -list -check
hack/tf-lint.sh
hack/yaml-lint.sh
hack/go-vet.sh ./...

# Note: go-test is skipped as is takes WAYYYYY too long to
# execute. The user should run go test in the directories
# where the changes have an effect on the code.
#hack/go-test.sh

hack/verify-codegen.sh
hack/verify-vendor.sh
