if [ $# -lt 1 ]; then
    echo "USAGE: bash $0 [NUM_SHAS]"
    echo "[NUM_SHAS] is an optional argument providing the number of SHAs to run the smallest project on"
    exit
fi

NUM_SHAS=$1

if [ "${NUM_SHAS}" == "" ]; then
    echo "No option provided, running with 2 SHAS..."
    NUM_SHAS=2
fi

SCRIPT_DIR=$(cd $(dirname $0) && pwd)

echo "[$0] Cleaning..."
bash ${SCRIPT_DIR}/clean.sh

echo "[$0] Running RPS-RPP-VMS on ${NUM_SHAS} SHAs..."
bash ${SCRIPT_DIR}/run_experiment.sh https://github.com/valfirst/jbehave-junit-runner ${SCRIPT_DIR}/project_revisions/jbehave-junit-runner.txt ${NUM_SHAS} nostats rps 3 true true
