#!/bin/bash

if [ $# -lt 4 ]; then
    echo "USAGE: bash $0 PROJECT_URL PATH_TO_REVISIONS NUMBER_OF_REVISIONS STATS [RUN_TYPE] [PROPERTY_SELECTION:{1,2,3}] [INCLUDE_LIBRARIES:bool] [INCLUDE_NONAFFECTED:bool]"
    echo "      RUN_TYPE must be one of {test, mop, rps, rps-vms, rps-rpp, rps-rpp-vms, vms rpp rpp-vms}"
    exit
fi

source ./util.sh

PROJECT_URL=$1
PATH_TO_REVISIONS=$2
NUMBER_OF_REVISIONS=$3
STATS=$4
RUN_TYPE=${5:-rps}
PS=${6:-3}
INCLUDE_LIBRARIES=${7:-false}
INCLUDE_NONAFFECTED=${8:-false}

PROJECT_NAME=$(get_project_name_from_GitHub_URL ${PROJECT_URL})
EXPERIMENT_ROOT=$(cd $(dirname $0) && pwd)
ENV_DIR=${EXPERIMENT_ROOT}/env-${PROJECT_NAME}
export EXTRA_MAVEN_ARGS="-Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dpmd.skip -Dxjc.skip -Djacoco.skip "
export LOCAL_M2_REPO=${ENV_DIR}/.m2/repository
export LOG_LABEL="[EMOP EXPERIMENT] "

function set_m2_home() {
    local mvn_running_mode=$1
    if [ ${mvn_running_mode} = 'test' ] || [ ${mvn_running_mode} = 'test-compile' ]; then    
        export M2_HOME=${ENV_DIR}/apache-maven-3.3.9
    elif [ ${mvn_running_mode} = 'mop' ]; then
        export M2_HOME=${ENV_DIR}/apache-maven-3.3.9-mop
    else
        export M2_HOME=${ENV_DIR}/apache-maven-3.3.9-emop
    fi
}

function run_mvn_test() {
  local proj_name=$1
  local mvn_mode=$2
  local log_file=$3
  local emop_options=${4:-''}
  local variant=${5:-''}

  local project_repo=${LOCAL_M2_REPO}-${PROJECT_NAME}
  local project_agent=${project_repo}/javamop-agent-emop/javamop-agent-emop/1.0/javamop-agent-emop-1.0.jar
  (
      export RVMLOGGINGLEVEL=UNIQUE
      old_path=$PATH
      set_m2_home ${mvn_mode}
      export PATH=${M2_HOME}/bin:${PATH}
      echo "M2_HOME: ${M2_HOME}"
      echo "PATH: ${PATH}"
      set -o xtrace
      mvn clean
      if [ ${mvn_mode} == "test" ]; then
          echo ${LOG_LABEL}----Executing Maven test
          time mvn test -fae ${EXTRA_MAVEN_ARGS} -Dmaven.repo.local=${project_repo}
      elif [ ${mvn_mode} == "test-compile" ]; then
          echo ${LOG_LABEL}----Executing Maven test-compile
          time mvn clean test-compile -fae ${EXTRA_MAVEN_ARGS} -Dmaven.repo.local=${project_repo}
      elif [ ${mvn_mode} == "mop" ]; then
          echo ${LOG_LABEL}----Executing mop
          time mvn test -fae ${EXTRA_MAVEN_ARGS} -Dmaven.repo.local=${project_repo}
      elif [ ${mvn_mode} == "rps" ]; then
          echo ${LOG_LABEL}----Executing emop:rps variant ${variant}
          time mvn emop:rps -DjavamopAgent=${project_agent} -fae ${EXTRA_MAVEN_ARGS} ${emop_options} -Dmaven.repo.local=${project_repo} -e
      elif [ ${mvn_mode} == "rps-vms" ]; then
          echo ${LOG_LABEL}----Executing emop:rps-vms variant ${variant}
          time mvn emop:rps-vms -DjavamopAgent=${project_agent} -fae ${EXTRA_MAVEN_ARGS} ${emop_options} -Dmaven.repo.local=${project_repo} -DforceSave -e
      elif [ ${mvn_mode} == "vms" ]; then
          echo ${LOG_LABEL}----Executing emop:vms
          time mvn emop:vms -DjavamopAgent=${project_agent} -fae ${EXTRA_MAVEN_ARGS} -Dmaven.repo.local=${project_repo} -DforceSave=true -e
      elif [ ${mvn_mode} == "rpp" ]; then
          echo ${LOG_LABEL}----Executing emop:rpp
          time mvn emop:rpp -DjavamopAgent=${project_agent} -fae ${EXTRA_MAVEN_ARGS} -Dmaven.repo.local=${project_repo}
      elif [ ${mvn_mode} == "rps-rpp" ]; then
          echo ${LOG_LABEL}----Executing emop:rps-rpp variant ${variant}
          time mvn emop:rps-rpp -DjavamopAgent=${project_agent} -fae ${EXTRA_MAVEN_ARGS} ${emop_options} -Dmaven.repo.local=${project_repo}
      elif [ ${mvn_mode} == "rpp-vms" ]; then
          echo ${LOG_LABEL}----Executing emop:rpp-vms
          time mvn emop:rpp-vms -DjavamopAgent=${project_agent} -fae ${EXTRA_MAVEN_ARGS} -Dmaven.repo.local=${project_repo} -DforceSave=true -e
      elif [ ${mvn_mode} == "rps-rpp-vms" ]; then
          echo ${LOG_LABEL}----Executing emop:rps-rpp-vms
          time mvn emop:rps-rpp-vms -DjavamopAgent=${project_agent} -fae ${EXTRA_MAVEN_ARGS} ${emop_options} -Dmaven.repo.local=${project_repo} -DforceSave=true -e
      fi
      set +o xtrace
      export PATH=${old_path}
  ) &> ${log_file}
}

# Checkout the given project to the version and save to log
function checkout_version {
  local project_name=$1
  local version=$2

  mkdir -p data/generated-data/${project_name}/${version}
  (
    cd experiment-projects/${project_name}
    git checkout -f ${version} &> ${EXPERIMENT_ROOT}/$(experiment_data_path ${project_name} ${version})/checkout-log.txt
  )
}

# Runs a single experiment with the provided revisions file
function run_single_experiment {
  local revisions_file=$1
  local project_url=$2
  local number_of_revisions=$3

  local project_name=$(get_project_name_from_GitHub_URL ${project_url})

  bash ${EXPERIMENT_ROOT}/setup.sh ${STATS} ${project_name}
  clone_repository ${project_url}
  local iteration=0
  echo ${LOG_LABEL}Running on project: ${project_name}
  local project_data_root=${EXPERIMENT_ROOT}/data/generated-data/${project_name}
  if [ ! -d ${project_data_root} ]; then
    mkdir -p ${project_data_root}
  fi

  og_agent=${project_data_root}/original-javamop-agent-emop-1.0.jar
  cp ${LOCAL_M2_REPO}-${PROJECT_NAME}/javamop-agent-emop/javamop-agent-emop/1.0/javamop-agent-emop-1.0.jar ${og_agent}

  # Override previous results
  if [ -f ${project_data_root}/results.csv ]; then
    rm ${project_data_root}/results.csv
  fi

  # Set flags for run
  local library_indicator=''
  local library_arg=''
  local non_affected_indicator=''
  local non_affected_arg=''
  local closure_arg=''
  if [ ${INCLUDE_LIBRARIES} = 'false' ]; then
      library_indicator='l'
      library_arg='-DincludeLibraries=false'
  fi
  if [ ${INCLUDE_NONAFFECTED} = 'false' ]; then
      non_affected_indicator='c'
      non_affected_arg='-DincludeNonAffected=false'
  fi
  closure_arg="-DclosureOption=PS${PS}"
  variant="ps${PS}${non_affected_indicator}${library_indicator}"
  starts_directory_arg="-DstartsDirectoryPath=.${variant}"

  print_mop_record_header ${project_data_root}/mop-results.csv
  print_emop_record_header ${project_data_root}/${variant}-results.csv ${PS} ${library_indicator} ${non_affected_indicator}
  
  # Append a dummy column, otherwise it will break data processing
  # echo ",dummy" >> ${project_data_root}/results.csv
  while read -r version; do
      [[ $version =~ ^#.* ]] && continue # skips projects that have hash in front
      (( iteration++ ))
      echo ${LOG_LABEL}--Running with version: ${version} [${iteration}/${number_of_revisions}]
      # For each revision, do the following:
      checkout_version ${project_name} ${version}
      (
	  cd ${EXPERIMENT_ROOT}/experiment-projects/${project_name}
	  treat_special ${project_name}
      )
      local data_path=${EXPERIMENT_ROOT}/$(experiment_data_path ${project_name} ${version})
      (
          cd experiment-projects/${project_name}
          run_mvn_test ${project_name} "test-compile" ${data_path}/compile-log.txt
          find "src/test" -name "*.java" > ${data_path}/test-files.txt
          if [ ${RUN_TYPE} = 'test' ]; then
	      run_mvn_test ${project_name} "test" ${data_path}/test-log.txt
          elif [ ${RUN_TYPE} = 'mop' ]; then
              run_mvn_test ${project_name} "test" ${data_path}/test-log.txt
              run_mvn_test ${project_name} "mop" ${data_path}/mop-log.txt
	      if [ -f violation-counts ]; then
                  mv violation-counts ${data_path}/mop-violation-counts
	      fi
              print_mop_record_body ${project_data_root}/mop-results.csv ${project_data_root} ${version}
              cp ${project_data_root}/mop-results.csv ${EXPERIMENT_ROOT}/results/${project_name}-mop-results.csv
          elif [ ${RUN_TYPE} = 'rps' ] || [ ${RUN_TYPE} = 'rps-vms' ] || [ "${RUN_TYPE}" = 'rps-rpp' ] || [ ${RUN_TYPE} = 'rps-rpp-vms' ]; then
	      # Content of the original big loop
	      cp ${og_agent} ${LOCAL_M2_REPO}-${PROJECT_NAME}/javamop-agent-emop/javamop-agent-emop/1.0/javamop-agent-emop-1.0.jar
	      run_mvn_test ${project_name} ${RUN_TYPE} ${data_path}/${variant}-log.txt "${closure_arg} ${non_affected_arg} ${library_arg} ${starts_directory_arg}" ${variant}
              # TODO: Hard-coded for now
	      # After each run, move violation counts over and rename it to something like ps3cl-violation-counts
	      if [ -f violation-counts ]; then
		  mv violation-counts ${data_path}/${variant}-violation-counts
	      fi
              # identify MMMP
              (
                  ws=${EXPERIMENT_ROOT}/experiment-projects/${project_name}
                  for artifact in $( find ${ws} -name ".${variant}" ); do
                      artifact_dir_ident=$( echo "${artifact}" | sed "s:${ws}/::g" )
	              mkdir -p "${data_path}/$(dirname "${artifact_dir_ident}")"
	              cp -R "${artifact}" "${data_path}/${artifact_dir_ident}"
                  done
              )
	      # copy the used/changed version of javamop agent to debug
	      (
		  # FIXME: this is a rather rough way to ensure that each invocation of emop uses a fresh javamop agent
		  mv ${LOCAL_M2_REPO}-${PROJECT_NAME}/javamop-agent-emop/javamop-agent-emop/1.0/javamop-agent-emop-1.0.jar ${EXPERIMENT_ROOT}/experiment-projects/${project_name}/.${variant}
		  cp ${og_agent} ${LOCAL_M2_REPO}-${PROJECT_NAME}/javamop-agent-emop/javamop-agent-emop/1.0/javamop-agent-emop-1.0.jar
	  	  cp -r ${EXPERIMENT_ROOT}/experiment-projects/${project_name}/.${variant} ${data_path}
	      )
	      # End of the original big loop
	      # Write at the end of an execution cycle

	      print_emop_record_body ${project_data_root}/${variant}-results.csv ${project_data_root} ${version} ${RUN_TYPE} ${PS} ${library_indicator} ${non_affected_indicator}
	      echo "" >> ${project_data_root}/results.csv

	      # Copy the results over for easier views
	      mkdir -p ${EXPERIMENT_ROOT}/results
	      cp ${project_data_root}/${variant}-results.csv ${EXPERIMENT_ROOT}/results/${project_name}-${variant}-results.csv
          elif [ ${RUN_TYPE} = 'vms' ]; then
	      run_mvn_test ${project_name} "vms" ${data_path}/vms-log.txt
	      ws=${EXPERIMENT_ROOT}/experiment-projects/${project_name}
	      find "${ws}" \( -name '.starts' -o -name 'violation-counts' \) -print0 | while IFS= read -r -d '' artifact; do
	          artifact_dir_ident=$( echo "${artifact}" | sed "s:${ws}/::g" )
	          mkdir -p "${data_path}/$(dirname "${artifact_dir_ident}")"
	          cp -R "${artifact}" "${data_path}/${artifact_dir_ident}"
	      done
          fi
      )
  done < <( grep -v ^# ${revisions_file} | head -${number_of_revisions} )
}

setup_environment_variables
#echo "Usage: $0 <repository link> <project_revision_file> <number_of_revisions>"
run_single_experiment ${PATH_TO_REVISIONS} ${PROJECT_URL} ${NUMBER_OF_REVISIONS}

