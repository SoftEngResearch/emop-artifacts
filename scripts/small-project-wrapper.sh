if [ $# -lt 1 ]; then
    echo "USAGE: bash $0 RESULT_DIR [NUM_SHAS]"
    echo "where RESULT_DIR is the root directory of the emop-paper repo to write results to"
    echo "if RESULT_DIR is not a directory path containing rv-2023 subdirectory, then results will not be written."
    echo "[NUM_SHAS] is an optional argument providing the number of SHAs to run the smallest project on"
    exit
fi

RESULT_DIR=$1
NUM_SHAS=$2

if [ "${NUM_SHAS}" == "" ]; then
    echo "No option provided, running with 2 SHAS..."
    NUM_SHAS=2
fi

SCRIPT_DIR=$(cd $(dirname $0) && pwd)

echo "[$0] Cleaning..."
bash ${SCRIPT_DIR}/clean.sh

echo "[$0] Running RPS-RPP-VMS on ${NUM_SHAS} SHAs..."
bash ${SCRIPT_DIR}/run_experiment.sh https://github.com/valfirst/jbehave-junit-runner ${SCRIPT_DIR}/project_revisions/jbehave-junit-runner.txt ${NUM_SHAS} nostats rps 3 true true
