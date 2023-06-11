#!/bin/bash

source ./util.sh

if [ $# -ne 2 ] || ([ $1 != 'stats' ] && [ $1 != 'nostats' ]); then
    echo "USAGE: bash $0 <STATS> <PROJECT_NAME>"
    echo "where <STATS> describes the level of detail included in runs"
    echo "using 'stats' will include statistics"
    echo "using 'nostats' will not include statistics"
    echo "<PROJECT_NAME> specifies which project the environment setup is for"
    exit
fi

STATS=$1
PROJECT_NAME=${2:-''}

EXPERIMENT_ROOT=$(cd $(dirname "$0") && pwd)
ENV_DIR=${EXPERIMENT_ROOT}/env-${PROJECT_NAME}
mkdir -p ${ENV_DIR}
export LOCAL_M2_REPO=${ENV_DIR}/.m2/repository

function init_project_repo {
  if [ ! -d ${LOCAL_M2_REPO}-${PROJECT_NAME} ]; then
      mkdir -p ${LOCAL_M2_REPO}-${PROJECT_NAME}
      if [[ "${PROJECT_NAME}" == "OpenTripPlanner" || "${PROJECT_NAME}" == "jackson-core" || "${PROJECT_NAME}" == "commons-math" || "${PROJECT_NAME}" == "stream-lib" ]]; then
	  echo "Copying repository for result reproduction"
	  cp -r "/scratch/ay436/projects/.m2/repository/"* "${LOCAL_M2_REPO}-${PROJECT_NAME}" # TODO: Hard-coded for now
      fi
  fi
}

function get_repo_arg {
  local repo_arg=''
  if [ ! -z ${PROJECT_NAME} ]; then
    repo_arg="-Dmaven.repo.local=${LOCAL_M2_REPO}-${PROJECT_NAME}"
  fi
  echo ${repo_arg}
}

function setup_aspectj {
  if [ ! -d ${ENV_DIR}/aspectj1.8 ]; then
    (
      cd ${ENV_DIR}
      wget https://www.cs.cornell.edu/courses/cs6156/2020fa/resources/aspectj1.8.tgz
      tar -xzf aspectj1.8.tgz && rm aspectj1.8.tgz
    )
  fi
}

function setup_rvmonitor {
  if [ ! -d ${ENV_DIR}/rv-monitor ]; then
    (
      cd ${ENV_DIR}
      git clone https://github.com/owolabileg/rv-monitor.git
    )
  fi
  (
    cd ${ENV_DIR}/rv-monitor
    if [ ${STATS} = 'stats' ]; then
      git checkout statistics
    else
      git checkout master
    fi
    mvn install -DskipTests -DskipDocs -fn $(get_repo_arg)
  )
}

function setup_javamop {
  if [ ! -d ${ENV_DIR}/javamop ]; then
    (
      cd ${ENV_DIR}
      git clone https://github.com/owolabileg/javamop.git
    )
  fi
  (
    cd ${ENV_DIR}/javamop
    if [ ${STATS} = 'stats' ]; then
      git checkout -f statistics
    else
      git checkout -f emop
    fi
    mvn install -DskipTests $(get_repo_arg)
  )
}

function setup_javamop_agent {
  if [ ! -d ${ENV_DIR}/javamop-agent-bundle ]; then
    (
      cd ${ENV_DIR}
      git clone https://github.com/SoftEngResearch/javamop-agent-bundle.git
    )
  fi
  (
      cd ${ENV_DIR}/javamop-agent-bundle
      if [ ${PROJECT_NAME} == "javapoet" ]; then
	  echo "javamop-agent-bundle: javapoet detected - deleting props/Arrays_MutuallyComparable.mop"
	  rm props/Arrays_MutuallyComparable.mop
      elif [ ${PROJECT_NAME} == "Yank" ]; then
	  echo "javamop-agent-bundle: Yank detected - deleting props/Arrays_SortBeforeBinarySearch.mop"
	  rm props/Arrays_SortBeforeBinarySearch.mop
      elif [ ${PROJECT_NAME} == "datasketches-java" ]; then
	  echo "javamop-agent-bundle: datasketches-java deteched - deleting props/Arrays_MutuallyComparable.mop"
	  rm props/Arrays_MutuallyComparable.mop
      fi
    # The following code works for both GNU sed and BSD sed
    # Reference: https://stackoverflow.com/questions/5694228/sed-in-place-flag-that-works-both-on-mac-bsd-and-linux
    if [ ${STATS} = 'stats' ]; then
      sed -i.tmp 's/-emop ${spec}/-emop ${spec} -s/' make-agent.sh
      rm make-agent.sh.tmp
      sed -i.tmp 's/*.rvm/*.rvm -s/' make-agent.sh
      rm make-agent.sh.tmp
    else
      sed -i.tmp 's/-emop ${spec} -s/-emop ${spec}/' make-agent.sh
      rm make-agent.sh.tmp
      sed -i.tmp 's/*.rvm -s/*.rvm/' make-agent.sh
      rm make-agent.sh.tmp
    fi
    bash make-agent.sh props agents quiet
    mvn install:install-file -Dfile=agents/JavaMOPAgent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" $(get_repo_arg)
    mvn install:install-file -Dfile=agents/JavaMOPAgent.jar -DgroupId="javamop-agent-emop" -DartifactId="javamop-agent-emop" -Dversion="1.0" -Dpackaging="jar" $(get_repo_arg)
  )
}

function setup_starts {
  if [ ! -d ${ENV_DIR}/starts ]; then
    (
      cd ${ENV_DIR}
      git clone https://github.com/TestingResearchIllinois/starts
    )
  fi
  (
    cd ${ENV_DIR}/starts
    git checkout impacted-both-ways
    mvn install -DskipTests -Dinvoker.skip $(get_repo_arg)
  )
}

function setup_emop {
  if [ ! -d ${ENV_DIR}/emop ]; then
    (
      cd ${ENV_DIR}
      git clone https://github.com/SoftEngResearch/emop
      git checkout rps-rpp-vms
    )
  fi
  (
      cd ${ENV_DIR}/emop
      git checkout rps-rpp-vms				  # FIXME: rpp-vms needs to be integrated into master
      mvn clean install -Dcheckstyle.skip $(get_repo_arg) # FIXME: need to fix checkstyle error
  )
}

function setup_mop_extension {
    if [ ! -d ${ENV_DIR}/mop-agent-extension ]; then
	cp -r mop-agent-extension ${ENV_DIR}
    fi
  (
    cd ${ENV_DIR}/mop-agent-extension
    mvn package
    mkdir -p ${ENV_DIR}/apache-maven-3.3.9-mop/lib/ext
    cp target/mop-agent-extension-1.0-SNAPSHOT.jar ${ENV_DIR}/apache-maven-3.3.9-mop/lib/ext
  )
}

function setup_emop_extension {
    if [ ! -d ${ENV_DIR}/emop-agent-extension ]; then
	cp -r emop-agent-extension ${ENV_DIR}
    fi
  (
    cd ${ENV_DIR}/emop-agent-extension
    mvn package
    mkdir -p ${ENV_DIR}/apache-maven-3.3.9-emop/lib/ext
    cp target/emop-agent-extension-1.0-SNAPSHOT.jar ${ENV_DIR}/apache-maven-3.3.9-emop/lib/ext
  )
  if [ ! -d ${ENV_DIR}/emop-extension ]; then
      cp -r emop-extension ${ENV_DIR}
  fi
  (
    cd ${ENV_DIR}/emop-extension
    mvn package
    mkdir -p ${ENV_DIR}/apache-maven-3.3.9-emop/lib/ext
    cp target/emop-extension-1.0-SNAPSHOT.jar ${ENV_DIR}/apache-maven-3.3.9-emop/lib/ext
  )
}

function setup_test_time_listener_extension() {
  if [ ! -d ${ENV_DIR}/test-time-listener-extension ]; then
      cp -r ${EXPERIMENT_ROOT}/test-time-listener-extension ${ENV_DIR}
  fi    
  (
      cd ${EXPERIMENT_ROOT}/test-time-listener
      mvn install $(get_repo_arg)
  )
  (
      cd ${ENV_DIR}/test-time-listener-extension
      mvn package
      mkdir -p ${ENV_DIR}/apache-maven-3.3.9/lib/ext
      cp target/test-time-listener-extension-1.0-SNAPSHOT.jar ${ENV_DIR}/apache-maven-3.3.9/lib/ext
  )
}

function prepare_maven {
  local mvn_zip=${ENV_DIR}/apache-maven-3.3.9.zip
  local mvn_dir=${ENV_DIR}/apache-maven-3.3.9
  local mvn_dir_mop=${ENV_DIR}/apache-maven-3.3.9-mop
  local mvn_dir_emop=${ENV_DIR}/apache-maven-3.3.9-emop
  if [ ! -d ${mvn_dir} ]; then
    wget http://mir.cs.illinois.edu/legunsen/tmp/apache-maven-3.3.9.zip -O ${mvn_zip}
    unzip -qq ${mvn_zip} -d ${ENV_DIR}
    rm -rf ${mvn_dir}/lib/ext/*.jar
    cp -r ${mvn_dir} ${mvn_dir_mop}
    cp -r ${mvn_dir} ${mvn_dir_emop}
    rm -f ${mvn_zip}
  fi
}

init_project_repo
setup_environment_variables
prepare_maven
mkdir -p ${ENV_DIR}
(
  cd ${ENV_DIR}
  setup_aspectj
  setup_rvmonitor
  setup_javamop
  setup_javamop_agent
  setup_starts
  setup_emop
)
setup_mop_extension
setup_emop_extension
setup_test_time_listener_extension
