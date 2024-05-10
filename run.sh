#!/bin/bash

########################################################
# Load in parse_yaml from
# https://github.com/mrbaseman/parse_yaml
########################################################
source <(curl -fsSL https://raw.githubusercontent.com/mrbaseman/parse_yaml/master/src/parse_yaml.sh)

########################################################
# Download tools.yaml to /tmp
########################################################
curl -o /tmp/tools.yaml https://raw.githubusercontent.com/nctiggy/prereq_tool/main/tools.yaml > /dev/null 2>&1

########################################################
# Parse out semver to int (eg. 18.24.123 -> 018024123
########################################################
function version { echo "$@" | awk -F. '{ printf("%03d%03d%03d\n",
                                        $1,$2,$3); }'; }

########################################################
# Check for existance of binary, that it is executable
# and minimum version
########################################################
binary_checks() {
    local __resultvar=$1
    local tool_binary=$2 version_command=$3
    printf "${cyan}Checking ${tool_binary} version.... "
    command -v $tool_binary > /dev/null 2>&1 && [ -x $(command -v $tool_binary) ]
    if [ $? -eq 0 ]
    then
      local result=$(eval "${version_command}")
      eval $__resultvar=$result
      echo $version_command
      return 0
    fi
    return 1
}

eval $(parse_yaml /tmp/tools.yaml)
check_tools() {
  for t in $tools_
  do
    local tool=$(eval echo "\${t}_")
    local name="${tool}name"
    local command="${tool}version_command"
    local minimum_version="${tool}minimum_version"
    echo "${!command}"
    binary_checks test "${!name}" "${!command}"
    if [[ $? -eq 0 ]]
    then
      echo "success ${test}"
    else
      echo "failure ${test}"
    fi
  done
}

check_tools
