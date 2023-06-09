#!/bin/bash

while read project; do
    cp "../emop-experiments/data/revisions/$project.txt" "project_revisions"
done < project_list.txt
