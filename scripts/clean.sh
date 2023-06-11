#!/bin/bash
# Clean up all the experiment data, please be careful with this!

EXPERIMENT_ROOT=$(cd $(dirname ${0}) && pwd)

rm -rf logs data/generated-data results experiment-projects rpp-data
rm -rf ${EXPERIMENT_ROOT}/apache*
rm -rf ${EXPERIMENT_ROOT}/env
rm -rf ${EXPERIMENT_ROOT}/env-*
rm -rf ${HOME}/.m2/repository-*
# Owolabi: I am not sure the following is a good idea...
if [ "$1" == "tmp" ]; then
    echo "cleaning user's files from /tmp"
    for i in $( find /tmp -user ${USER} ); do rm -rf ${i} ; done
fi
