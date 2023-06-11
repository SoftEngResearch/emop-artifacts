MODE=$1

(
    cd scripts
    bash run-single-project.sh https://github.com/valfirst/jbehave-junit-runner jbehave-junit-runner 2 ${MODE}
)
