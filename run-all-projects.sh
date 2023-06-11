MODE=$1
MAX_JOBS=$2 # How many projects you want to run at the same time
NUM_REVISIONS=${3:-2}

while read line; do
    url=$(echo "$line" | cut -d ' ' -f 1)
    name=$(echo "$line" | cut -d ' ' -f 2)
    echo "bash run-single-project.sh $url $name $NUM_REVISIONS ${MODE}" >> commands.tmp
done < project_url_and_name.txt

(
    cd scripts
    cat ../commands.tmp | parallel -j "$MAX_JOBS"
)
rm commands.tmp
