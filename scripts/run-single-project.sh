if [ $# -lt 4 ]; then
    echo "USAGE: bash $0 PROJECT_URL PROJECT_NAME [NUM_SHAS] [MODE:{all,one}]"
    echo "[NUM_SHAS] is an optional argument providing the number of SHAs to run the project on"
    echo "[MODE] is an optional argument for specifying whether to run only PS3 variant [one], or mop, tests, and [all] variants"
    exit
fi

PROJECT_URL=$1
PROJECT_NAME=$2
NUM_SHAS=$3
MODE=$4

if [ "${NUM_SHAS}" == "" ]; then
    echo "No [NUM_SHAS] provided, running with 2 SHAS..."
    NUM_SHAS=2
fi

if [ "${MODE}" == "" ]; then
    echo "No [MODE] provided, running with one RPS variant (ps3)..."
    MODE=one
fi

SCRIPT_DIR=$(cd $(dirname $0) && pwd)

echo "[$0] Cleaning..."
bash ${SCRIPT_DIR}/clean.sh

if [ "${MODE}" == "one" ]; then
    echo "[$0] Running RPS with PS3 on ${NUM_SHAS} SHAs..."
    bash ${SCRIPT_DIR}/run_experiment.sh ${PROJECT_URL} ${SCRIPT_DIR}/project_revisions/${PROJECT_NAME}.txt ${NUM_SHAS} nostats rps 3 true true
else
    echo "[$0] Running RPS with MOP and all variants on ${NUM_SHAS} SHAs..."
    bash ${SCRIPT_DIR}/run_experiment.sh ${PROJECT_URL} ${SCRIPT_DIR}/project_revisions/${PROJECT_NAME}.txt ${NUM_SHAS} mop
    for ps in 1 2 3
              for library in false true; do
                  for non_affected in false true; do
                          bash ${SCRIPT_DIR}/run_experiment.sh ${PROJECT_URL} ${SCRIPT_DIR}/project_revisions/${PROJECT_NAME}.txt ${NUM_SHAS} nostats rps ${ps} ${library} ${non_affected}
                  done
        done
    done
fi
