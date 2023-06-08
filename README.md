# emop-artifacts

We have prepared the following artifacts:

* `project_list.txt`: A list in plain text format of the 22 projects that are used in our evaluation
* `project_name_to_id.csv`: A comma-separated table that has these two columns:
  * `project_name`: Name of the project
  * `project_id`: Short name of the project that is used in the paper
* `vms_data.csv`: A comma-separated table that has these three columns:
  * `project_name`: Name of the project
  * `vms_new_violations`: The sum of all new violations found by VMS across all commits of the project
  * `all_violations`: The sum of all violations, new and old combined, across all commits of the project
* `project_revisions`: A directory that contains file in the following format:
  * `${project_name}.txt`: A file that contains all the SHA hash values of a GitHub project's commits that we used in our evaluation. Lines that start with `#` represent commits that are not able to be evaluated upon because of various failures as commented next to them