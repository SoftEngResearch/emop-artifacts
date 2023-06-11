MODE=$1
NUM_REVISIONS=${2:-2}

while read line; do
    url=$(echo "$line" | cut -d ' ' -f 1)
    name=$(echo "$line" | cut -d ' ' -f 2)
    (
        cd scripts
        bash run-single-project.sh $url $name $NUM_REVISIONS ${MODE}
    )
done < project_url_and_name.txt

