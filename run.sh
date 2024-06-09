#!/bin/bash

########################################################
# Load in parse_yaml from
# https://github.com/mrbaseman/parse_yaml
########################################################
source <(curl -fsSL https://raw.githubusercontent.com/mrbaseman/parse_yaml/master/src/parse_yaml.sh)

########################################################
# Download tools.yaml to /tmp
########################################################
default_tools() {
  curl -o /tmp/tools.yaml https://raw.githubusercontent.com/nctiggy/prereq_tool/main/tools.yaml > /dev/null 2>&1
  tools_yaml="/tmp/tools.yaml"
}


########################################################
# Set color vars
########################################################
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
cyan=`tput setaf 6`
blue=`tput setaf 4`
magenta=`tput setaf 5`

########################################################
# Parse out semver to int (eg. 18.24.123 -> 018024123
########################################################
function version { echo "$@" | awk -F. '{ printf("%03d%03d%03d\n",
                                        $1,$2,$3); }'; }

########################################################
# Check for existance of binary, that it is executable
# and minimum version
########################################################
binary_good() {
    local __resultvar=$1
    local tool_binary=$2 version_command=$3
    printf "${cyan}Checking ${tool_binary} version.... "
    command -v $tool_binary > /dev/null 2>&1 && [ -x "$(command -v $tool_binary)" ]
    if [ $? -eq 0 ]
    then
      local result=$(eval "${version_command}")
      eval $__resultvar=$result
      return 0
    fi
    return 1
}

########################################################
# This is the main function that loops through the tools
# yaml file and checks for existance and version
########################################################
check_tools() {
  for t in $tools_
  do
    current_version=0
    local tool=$(eval echo "\${t}_")
    local name="${tool}name"
    local command="${tool}version_command"
    local minimum_version="${tool}minimum_version"
    binary_good current_version "${!name}" "${!command}" && version_good ${!minimum_version} ${current_version}
    if [[ $? -eq 0 ]]
    then
      printf "${green}${current_version}\n${reset}"
    else
      failed_software=( "${failed_software[@]}" "${!name}" )
      if [ $current_version == "0" ]
      then
        printf "${red}Not Installed"
      else
        printf "${red}${current_version}"
      fi
      printf  " | minimum ver. ${!minimum_version}\n${reset}"
    fi
  done
}

install_tools() {
  local distro=$(cat /etc/os-release | grep '^ID=' | awk -F= '{gsub (/"/, "", $2); print $2}')
}

########################################################
# Function to validate the currently installed version
# meets or exceeds the minimum value required
########################################################
version_good() {
    local min_ver=$1 curr_ver=$2 re='^[0-9]+$'
    [[ $(version $curr_ver) =~ $re ]] && [ $(version $curr_ver) -ge $(version $min_ver) ]
    if [[ $? -eq 0 ]]
    then
      return 0
    fi
    return 1
}

usage=$(cat << EOM
Prereq tool. Check for installed software.

Options:
  [ --tools | -t ]      Specify tools yaml file location
  [ --use-repo-tools ]  Use the default tools.yaml in the main repo
  [ --accept | -y ]     Auto install unmet pre-reqs. No prompts
  [ --help | -h ]       Print this help message

Usage:
  ./run.sh --tools /tmp/tools_file.yaml --accept
  -- or --
  ./run.sh --use-repo-tools
EOM
)
main() {
  current_version=0
  eval $(parse_yaml "${tools_yaml}")
  check_tools
  echo ${failed_software[*]}
}

failed_software=()
[[ $# -eq 0 ]] && printf "Missing options!\n\n${usage}\n"
while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    "--tools"|"-t")
      tools_yaml=$2
      shift
      shift
      ;;
    "--use-repo-tools")
      default_tools
      shift
      ;;
    "--help"|"-h")
      printf "${usage}\n"
      exit 0
      ;;
    *)
      printf "Invalid Options: ${key}\n\n${usage}\n"
      exit 1
      ;;
  esac
done
main
