# emop-artifacts

## Pre-requisites

The scripts that we provide have only been tested on PCs running Ubuntu 20.4, Java 1.8, and Python 3.

## Data provided

* `project_list.txt`: A list in plain text format of the 22 projects that are used in our evaluation

* `project_url_and_name.txt`: A list containing project url and name separated by space

* `project_name_to_id.csv`: A comma-separated table that has these two columns:
  * `project_name`: Name of the project
  * `project_id`: Short name of the project that is used in the paper
  
* `vms_data.csv`: A comma-separated table that has these three columns:
  * `project_name`: Name of the project
  * `vms_new_violations`: The sum of all new violations found by VMS across all commits of the project
  * `all_violations`: The sum of all violations, new and old combined, across all commits of the project
  
* `project_revisions`: A directory that contains file in the following format:
  * `${project_name}.txt`: A file that contains all the SHA hash values of a GitHub project's commits that we used in our evaluation. Lines that start with `#` represent commits that are not able to be evaluated upon because of various failures as commented next to them
  
* `appendix.pdf`: Appendix of the paper. Contains various plots of the results of different configurations for selected projects

## Scripts for reproducing results

* `run-one-project.sh`: A script to run our experiments on one project (`jbehave-junit-runner`) in our experiments. There are two modes of running:

  * `bash run-one-project.sh one` will run RPS on two SHAs of the project using the PS3 variant (no 3rd-party library or non-affected class instrumentation)

  * `bash run-one-project.sh all` will run JavaMOP and RPS on two SHAs of the project using all RPS variants

* After running scripts with any of the commands above, the results will be in CSV files stored in the `scripts/results` directory

