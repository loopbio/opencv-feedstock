#!/bin/bash
CONFIG="linux_python2.7" .circleci/run_docker_build.sh
CONFIG="linux_python3.5" .circleci/run_docker_build.sh
CONFIG="linux_python3.6" .circleci/run_docker_build.sh
