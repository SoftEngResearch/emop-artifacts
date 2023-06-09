if [ $# -lt 1 ]; then
    echo "USAGE: bash $0 PAPER_DIR [NUM_SHAS]"
    echo "where PAPER_DIR is the root directory of the emop-paper repo to write results to"
    echo "if PAPER_DIR is not a directory path containing rv-2023 subdirectory, then results will not be written."
    echo "[NUM_SHAS] is an optional argument providing the number of SHAs to run the smallest project on"
    exit
fi

PAPER_DIR=$1
NUM_SHAS=$2

if [ "${NUM_SHAS}" == "" ]; then
    echo "No option provided, running with 5 SHAS..."
    NUM_SHAS=5
fi

SCRIPT_DIR=$(cd $(dirname $0) && pwd)

(
    git clone https://github.com/SoftEngResearch/emop-experiments
    cd emop-experiments
    git checkout -f cleanup
)

echo "[$0] Cleaning..."
bash ${SCRIPT_DIR}/emop-experiments/clean.sh

echo "[$0] Running RPS-RPP-VMS on ${NUM_SHAS} SHAs..."
bash ${SCRIPT_DIR}/emop-experiments/run_experiment.sh https://github.com/valfirst/jbehave-junit-runner ${SCRIPT_DIR}/data/revisions/jbehave-junit-runner.txt ${NUM_SHAS} nostats rps 3 true true