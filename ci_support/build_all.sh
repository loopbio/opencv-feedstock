#!/bin/bash
# Locally build linux packages; note this is a small convenience, use pen.py for the whole meat.

set -ex

pushd `dirname $0` > /dev/null
myDir=`pwd`
popd > /dev/null

LOGS_DIR="${myDir}/../build_artefacts/logs"
mkdir -p ${LOGS_DIR}

CONDA_PY=27 ${myDir}/run_docker_build.sh | tee ${LOGS_DIR}/py27.txt
CONDA_PY=36 ${myDir}/run_docker_build.sh | tee ${LOGS_DIR}/py36.txt
CONDA_PY=35 ${myDir}/run_docker_build.sh | tee ${LOGS_DIR}/py35.txt
