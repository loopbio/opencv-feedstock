#!/bin/bash

# Can run from anywhere...
pushd `dirname $0` > /dev/null
myDir=`pwd`
popd > /dev/null

# Build package variants
CONFIG="linux_python2.7" ${myDir}/.circleci/run_docker_build.sh
CONFIG="linux_python3.6" ${myDir}/.circleci/run_docker_build.sh

# Clean cruft
rm -f ${myDir}/.ci_support/clobber_*
