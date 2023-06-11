#!/bin/bash

EXPERIMENT_ROOT=$(cd $(dirname $0) && pwd)
ENV_DIR=${EXPERIMENT_ROOT}/env

# Prints the header for the mop part of the result table
function print_mop_record_header {
  local result_file=$1

  echo -n "SHA,\
#classes,\
#tests,\
test-compile (s),\
test (s),\
mop (s),\
mop#violations,\
mop#unique,\
mop#monitors,\
mop#events" \
    >> ${result_file}
}

function print_mop_record_body {
  local result_file=$1
  local project_data_root=$2
  local version=$3

  local class_count=$(cat ${project_data_root}/${version}/ps1-log.txt | grep '\[eMOP\] Total number of classes: ' | rev | cut -f 1 -d ' ' | rev | tr -d "\n")
  local test_count=$(cat ${project_data_root}/${version}/test-files.txt | wc -l | xargs | tr -d "\n")
  local compile_time=$(get_time_from_log ${project_data_root}/${version}/compile-log.txt | tr -d "\n")
  local test_time=$(get_time_from_log ${project_data_root}/${version}/test-log.txt | tr -d "\n")
  local mop_time=$(get_time_from_log ${project_data_root}/${version}/mop-log.txt | tr -d "\n")
  local total_violations=0
  local unique_violations=0
  if [ -f ${project_data_root}/${version}/mop-violation-counts ]; then
    total_violations=$(uniq ${project_data_root}/${version}/mop-violation-counts | awk '{ print $1 }' | paste -sd+ - | bc | tr -d "\n")
    unique_violations=$(uniq ${project_data_root}/${version}/mop-violation-counts | wc -l | xargs | tr -d "\n")
  fi
  local mop_monitors=$(cat "$project_data_root/$version/mop-log.txt" | grep '#monitors:' | awk '{ print $2 }' | paste -sd+ - | bc | tr -d "\n")
  local mop_events=$(cat "$project_data_root/$version/mop-log.txt" | grep '#event' | awk '{ print $4 }' | paste -sd+ - | bc | tr -d "\n")

  echo "${version},\
${class_count},\
${test_count},\
${compile_time},\
${test_time},\
${mop_time},\
${total_violations},\
${unique_violations},\
${mop_monitors},\
${mop_events}," \
       >> ${result_file}
}

# Obtains the project name
function get_project_name_from_GitHub_URL {
  local project_url=$1
  echo ${project_url} | cut -d '/' -f 5
}

# Clones the repository of the given URL
function clone_repository {
  local project_url=$1
  mkdir -p experiment-projects
  local project_name=$(get_project_name_from_GitHub_URL ${project_url})
  (
    cd experiment-projects
    if [ -d ${project_name} ]; then
      rm -rf ${project_name}
    fi
    git clone ${project_url}
  )
}

# Obtains the directory to experiment data
function experiment_data_path {
  local project_name=$1
  local project_version=$2
  echo "data/generated-data/$project_name/$project_version"
}

# Outputs the real time from a file
function get_time_from_log() {
    local mvn_log=$1
    local t=$(tail ${mvn_log} | grep ^real | cut -f2 )
    min=$(echo ${t} | cut -dm -f1)
    sec=$(echo ${t} | cut -d\. -f1 | cut -dm -f2)
    frac=$(echo ${t} | cut -d. -f2 | tr -d 's')
    time=$(echo "scale=3;(${min} * 60)+${sec}+(${frac}/1000)" | bc -l)
    local fail=$(grep "BUILD FAILURE" ${mvn_log})
    if [ ! -z "${fail}" ]; then time="-"${time}; fi
    echo ${time}
}

# Gets the total number of monitors and events
function get_stat_info {
    local log=$1
    local monitors=''
    local events=''
    if uname -a | grep Darwin &> /dev/null; then
      monitors=$(grep -a ^#monitors ${log} | cut -d: -f2 | awk '{ total += $1} END {print total}')
      events=$(grep -a ^#event ${log} | cut -d: -f2 | awk '{ total += $1} END {print total}')
    else
      monitors=$(grep -a ^#monitors ${log} | cut -d: -f2 | paste -sd+ | bc -l)
      events=$(grep -a ^#event ${log} | cut -d: -f2 | paste -sd+ | bc -l)
    fi
    echo ${monitors},${events}
}

function setup_environment_variables {
  # AspectJ-Related
  export ASPECTJ_HOME=${ENV_DIR}/aspectj1.8
  export CLASSPATH=$ASPECTJ_HOME/lib/aspectjrt.jar:$ASPECTJ_HOME/lib/aspectjtools.jar:$ASPECTJ_HOME/lib/aspectjweaver.jar:${ENV_DIR}/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:$CLASSPATH
  export PATH=$ASPECTJ_HOME/bin:${ENV_DIR}/rv-monitor/target/release/rv-monitor/bin:${ENV_DIR}/javamop/target/release/javamop/javamop/bin:${PATH}
  echo "NEW ASPECTJ_HOME: ${ASPECTJ_HOME}"
  echo "NEW CLASSPATH: ${CLASSPATH}"
  echo "NEW PATH: ${PATH}"
}

function treat_special() {
    local p_name=$1
    echo "input to treat_special: ${p_name}"
    if [ ${p_name} == "model-citizen" ]; then
	find -name SkipReferenceFieldPolicyTest.java | xargs rm -f
	find -name MappedSingletonPolicyTest.java | xargs rm -f
    elif [ ${p_name} == "underscore-java" ]; then
	find -name _Test.java | xargs rm -f
    elif [ ${p_name} == "joda-time" ]; then
	find -name TestDateTimeComparator.java | xargs rm -f
	find -name TestAll.java | xargs sed -i 's/.*TestDateTimeComparator.*//g'
    fi
    if [ "${p_name}" == "stream-lib" ]; then
	find . -name TDigestTest.java | xargs rm -f
    fi
    if [ "${p_name}" == "jackson-core" ]; then
	sed -i 's|<artifactId>junit</artifactId>|<artifactId>junit</artifactId><version>4.13.2</version>|g' pom.xml
    fi
    if [ ${p_name} == "imglib2" ]; then
        git checkout pom.xml
	cp pom.xml pom.xml.bak
	head -n -1 pom.xml.bak > pom.xml
	echo "	<build>
	<plugins>
	  <plugin>
	    <groupId>org.apache.maven.plugins</groupId>
	    <artifactId>maven-surefire-plugin</artifactId>
	    <version>2.22.1</version>
	    <configuration>
	      <argLine>-Xms20g -Xmx20g</argLine>
	    </configuration>
	  </plugin>
	</plugins>
	</build>
" >> pom.xml
	tail -1 pom.xml.bak >> pom.xml
    fi
    if [ ${p_name} == "infomas-asl" ]; then
        find -name AnnotationDetectorTest.java | xargs rm -f
        find -name FileIteratorTest.java | xargs rm -f
    fi
    if [ ${p_name} == "geoserver-manager" ]; then
        find -name GSLayerEncoder21Test.java | xargs rm -f
    fi
    if [ ${p_name} == "underscore-java" ]; then
        find -name LodashTest.java | xargs rm -f
    fi
    if [ ${p_name} == "scribe-java" ]; then
        git checkout -f pom.xml
        sed -i "s|<release>\${java.release}</release>|<source>1.7</source><target>1.7</target>|g" pom.xml
    fi
    if [ ${p_name} == "multi-thread-context" ]; then
        find -name JavassistTest.kt | xargs rm -f
    fi
    if [ ${p_name} == "jackson-databind" ]; then
        find -name TestTypeFactoryWithClassLoader.java | xargs rm -f
    fi
    if [ ${p_name} == "commons-imaging" ]; then
        find -name ByteSourceImageTest.java | xargs rm -f
        find -name BitmapRoundtripTest.java | xargs rm -f
        find -name GrayscaleRountripTest.java | xargs rm -f
        find -name LimitedColorRoundtripTest.java | xargs rm -f
    fi
    if [ ${p_name} == "commons-lang" ]; then
        find -name FastDateFormatTest.java | xargs rm -f
        find -name EventListenerSupportTest.java | xargs rm -f
        find -name EventUtilsTest.java | xargs rm -f
        find -name StrTokenizerTest.java | xargs rm -f
    fi
    if [ ${p_name} == "OpenTripPlanner" ]; then
        find -name TestIntermediatePlaces.java | xargs rm -f
        find -name LinkingTest.java | xargs rm -f
        find -name TestTransfers.java | xargs rm -f
        find -name TestBanning.java | xargs rm -f
        find -name TestFares.java | xargs rm -f
        find -name GraphIndexTest.java | xargs rm -f
        find -name PointSetTest.java | xargs rm -rf
        find -name InitialStopsTest.java | xargs rm -f
        find -name CSVPopulationTest.java | xargs rm -f
        find -name EncodedPolylineJSONSerializerTest.java | xargs rm -f
        find -name BanoGeocoderTest.java | xargs rm -f
    fi
    if [ ${p_name} == "commons-dbcp" ]; then
        find -name TestManagedDataSourceInTx.java | xargs rm -f
        find -name TestDriverAdapterCPDS.java | xargs rm -f
        find -name TestAbandonedBasicDataSource.java | xargs rm -f
        find -name TestPerUserPoolDataSource.java | xargs rm -f
    fi
    if [ ${p_name} == "commons-io" ]; then
        find -name ValidatingObjectInputStreamTest.java | xargs rm -f
        find -name FileCleaningTrackerTestCase.java | xargs rm -f;
        find -name FileCleanerTestCase.java | xargs rm -f
        sed -i 's/Xmx25M/Xmx8000M/' pom.xml
    fi
    if [ "${p_name}" == "commons-math" ]; then
	find . -name LogNormalDistributionTest.java | xargs rm -f
	find . -name ChiSquaredDistributionTest.java | xargs rm -f
	find . -name NakagamiDistributionTest.java | xargs rm -f
	find . -name LegendreHighPrecisionParametricTest.java | xargs rm -f
	find . -name LegendreParametricTest.java | xargs rm -f
	find . -name BaseRuleFactoryTest.java | xargs rm -f
	find . -name KohonenTrainingTaskTest.java | xargs rm -f
	find . -name HermiteParametricTest.java | xargs rm -f
	find . -name FirstMomentTest.java | xargs rm -f
	find . -name RandomUtilsDataGeneratorJDKSecureRandomTest.java | xargs rm -f
	find . -name KendallsCorrelationTest.java | xargs rm -f
	# find . -name KolmogorovSmirnovTestTest.java | xargs rm -f  # method testTwoSampleProductSizeOverflow times out after 5s with MOP, but some other class depends on it
	find . -name Providers32ParametricTest.java | xargs rm -f # java.lang.NoClassDefFoundError: Could not initialize class org.apache.commons.math4.rng.ProvidersList
	find . -name Providers64ParametricTest.java | xargs rm -f # java.lang.NoClassDefFoundError: Could not initialize class org.apache.commons.math4.rng.ProvidersList
	find . -name ProvidersCommonParametricTest.java | xargs rm -f # java.lang.NoClassDefFoundError: Could not initialize class org.apache.commons.math4.rng.ProvidersList
	find . -name FastMathTest.java | xargs rm -f # method testPowAllSpecialCases times out after 20s with MOP
	# sed -i '0,|<configuration>|s||<configuration><forkCount>0</forkCount>|' pom.xml
    fi
    if [ "${p_name}" == "mp3agic" ]; then
	find -name Mp3RetagTest.java | xargs rm -f # fails when run with mop
    fi
}

function print_emop_record_header {
    local result_file=$1
    local ps_variant=$2
    local lib_indicator=$3
    local affected_klas_indicator=$4
    local project_version=$5
    local variant="ps${ps_variant}${affected_klas_indicator}${lib_indicator}"    
    echo "SHA,${variant} (s),\
            ${variant}#violations,\
            ${variant}#unique,\
            ${variant}#specs,\
            ${variant}#impactedClasses,\
            ${variant} ImpactedClasses(ms),\
            ${variant} compile-time weaving (ms),\
            ${variant} process message (ms),\
            ${variant} write specs to disk (ms),\
            ${variant} change aop-ajc.xml (ms),\
            ${variant}#monitors,\
            ${variant}#events" >> ${result_file}
}

function print_emop_record_body {
  local result_file=$1
  local project_data_root=$2
  local version=$3
  local run_type=$4
  local ps_variant=$5
  local lib_indicator=$6
  local affected_klas_indicator=$7
  local variant="ps${ps_variant}${affected_klas_indicator}${lib_indicator}"
  
  log_file=${project_data_root}/${version}/${variant}-log.txt
  
  local emop_time=$(get_time_from_log ${log_file} | tr -d "\n")
  if [[ "${run_type}" == "rps-rpp-vms" || "${run_type}" == "rps-rpp" ]]; then
      background_time=$( python3 ${EXPERIMENT_ROOT}/paper/compute-time.py ${log_file} | cut -d, -f2 )
      if [[ "${emop_time}" != -* ]]; then
          emop_time=$( echo "${emop_time} - ${background_time}" | bc -l )
      else
          emop_time=$( echo "${emop_time} + ${background_time}" | bc -l ) # "subtracting" from negative numbers
      fi
  fi
  local emop_specs=0
  if [ -f ${project_data_root}/${version}/.${variant}/classToSpecs.txt ]; then
      emop_specs=$(wc -l ${project_data_root}/${version}/.${variant}/classToSpecs.txt | xargs | cut -f 1 -d ' ' | tr -d "\n")
  fi
  local impacted_class_count=0
  if [ -f ${project_data_root}/${version}/.${variant}/impacted-classes ]; then
      impacted_class_count=$(wc -l ${project_data_root}/${version}/.${variant}/impacted-classes | xargs | cut -f 1 -d ' ' | tr -d "\n")
  fi
  local emop_violations=''
  local emop_unique_violations=''
  if [ ${impacted_class_count} -ne 0 ]; then
      emop_violations=$(uniq ${project_data_root}/${version}/${variant}-violation-counts | awk '{ print $1 }' | paste -sd+ - | bc | tr -d "\n")
      emop_unique_violations=$(uniq ${project_data_root}/${version}/${variant}-violation-counts | wc -l | xargs | tr -d "\n")
  else
      emop_specs=0
  fi
  local emop_monitors=$(cat "$project_data_root/$version/${variant}-log.txt" | grep '#monitors:' | awk '{ print $2 }' | paste -sd+ - | bc | tr -d "\n")
  local emop_events=$(cat "$project_data_root/$version/${variant}-log.txt" | grep '#event' | awk '{ print $4 }' | paste -sd+ - | bc | tr -d "\n")

  # TODO: for c variants, might want to record time to replace BaseAspect
  local replace_base_aspect_time=$(cat ${project_data_root}/${version}/${variant}-log.txt | grep '\[eMOP Timer\]' | grep 'Generating aop' | rev | cut -f2 -d' ' | rev | tr -d "\n")

  echo "${version}, ${emop_time},\
$emop_violations,\
$emop_unique_violations,\
$emop_specs,\
$impacted_class_count,\
$(cat ${project_data_root}/${version}/${variant}-log.txt | grep '\[eMOP Timer\]' | grep 'ImpactedClasses' | rev | cut -f2 -d' ' | rev | tr -d "\n"),\
$(cat ${project_data_root}/${version}/${variant}-log.txt | grep '\[eMOP Timer\]' | grep 'Compile-time' | rev | cut -f2 -d' ' | rev | tr -d "\n"),\
$(cat ${project_data_root}/${version}/${variant}-log.txt | grep '\[eMOP Timer\]' | grep 'Compute affected' | rev | cut -f2 -d' ' | rev | tr -d "\n"),\
$(cat ${project_data_root}/${version}/${variant}-log.txt | grep '\[eMOP Timer\]' | grep 'Write affected' | rev | cut -f2 -d' ' | rev | tr -d "\n"),\
$replace_base_aspect_time,\
$emop_monitors,\
$emop_events" >> ${result_file}
}
