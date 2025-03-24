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
check="\xE2\x9C\x93"
cross="X"
spin='-\|/'

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
      local result=$(eval "${version_command}" 2> /dev/null)
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
  local __resultvar=$1
  shift
  local pack_tools=("$@")
  local result=()
  for t in $tools_
  do
    current_version=0
    local tool=$(eval echo "\${t}_")
    local name="${tool}name"
    [[ ! " ${pack_tools[*]} " =~ "${!name}" ]] && continue
    name="${!name}"
    tools=( "${pack_tools[@]/$name}" )
    local command="${tool}version_command"
    local minimum_version="${tool}minimum_version"
    binary_good current_version "${name}" "${!command}" && version_good ${!minimum_version} ${current_version}
    if [[ $? -eq 0 ]]
    then
      printf "${green}${current_version}\n${reset}"
    else
      result=( "${result[@]}" "${name}" )
      if [[ $current_version == "0" ]]
      then
        printf "${red}Not Installed"
      else
        printf "${red}${current_version}"
      fi
      printf  " | minimum ver. ${!minimum_version}\n${reset}"
    fi
  done
  eval $__resultvar="'${result[@]}'"
}

########################################################
# Function that builds an array of apps to install
# based off of the selected tools_pack arg
########################################################

get_tool_pack() {
  local __resultvar=$1
  local result=()
  for tp in $tool_packs_
  do
    local name=$(eval echo "\${tp}_name")
    [[ "${tool_pack}" != "${!name}" ]] && continue
    local tools=$(eval echo "\${tp}_tools_")
    for tpt in ${!tools}
    do
      result=( "${result[@]}" "${!tpt}" )
    done
    break
  done
  [[ ${#result[@]} -eq 0 ]] && echo "${red}--tool-pack ${tool_pack} not found or no tools in pack${reset}" && exit 1
  eval $__resultvar="'${result[@]}'"
}

########################################################
# Function that prints the install status
########################################################
install_status() {
  local tool_name=$1 disp_char=$2 char_color=$3 fail_msg=$4
  printf "\r${cyan}[${!char_color}${disp_char}${cyan}] Installing ${tool_name} ${red}${fail_msg}${reset}"
}

########################################################
# Function that loops through all the tools not
# installed or at the correct version and runs through
# the install_steps
########################################################
install_tools() {
  local distro=$(cat /etc/os-release | grep '^ID=' | awk -F= '{gsub (/"/, "", $2); print $2}')
  local kernel=$(uname | awk '{print tolower($0)}')
  local install_tools=("$@")
  for t in $tools_
  do
    local tool=$(eval echo "\${t}_")
    local name="${tool}name"
    local failed_step=0
    [[ ! " ${install_tools[*]} " =~ "${!name}" ]] && continue
    install_status ${!name} " " "green"
    local install_var="${tool}install_commands_"
    if [[ -z ${!install_var+set} ]]
    then
      install_status ${!name} "${cross}" "red" "No install steps listed in the yaml"
      echo
      continue
    fi
    [[ " ${!install_var} " =~ "${kernel}" ]] && install_steps="${install_var}${kernel}_"
    [[ " ${!install_var} " =~ "${distro}" ]] && install_steps="${install_var}${distro}_"
    [[ " ${!install_var} " =~ "all" ]] && install_steps=( "${install_steps[@]}" "${install_var}all_" )
    for c in ${!install_steps}
    do
      eval "(${!c}) >/dev/null 2>&1 &"
      pid=$!
      while kill -0 $pid 2>/dev/null
      do
        i=$(( (i+1) %4 ))
        install_status ${!name} "${spin:$i:1}" "cyan"
        sleep .1
      done
      wait $pid
      local exit_status=$?
      if [[ ${exit_status} -ne 0 ]]
      then
        install_status ${!name} "${cross}" "red" "Install step ${c:0-1} failed: Exit code ${exit_status}"
        failed_step=1
        echo
        break
      fi
    done
    [[ $failed_step -ne 1 ]] && install_status ${!name} "${check}" "green" && echo
  done
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

########################################################
# Function that detirmines if the script is running with
# elevated privs or not
########################################################
is_elevated() {
  local is_sudo=1 is_root=1
  [[ ! $(sudo -l &> /dev/null) ]] && is_sudo=1 || is_sudo=0
  [[ $EUID -ne 0 ]] && is_root=1 || is_root=0
  [[ $(($is_root + $is_sudo)) < 2 ]] && return 0 || return 1
}

ask_to_install() {
  local result="" __resultvar=$1
  if [ -z ${accept+x} ]
  then
    printf "${magenta}Install required software? (Y/n): ${reset}"
    read result
    [[ "${result}" == "" ]] && result="y"
    result=$(echo ${result} | awk '{print tolower($0)}')
  else
    result="y"
  fi
  eval $__resultvar="'$result'"
}

usage=$(cat << EOM
Prereq tool. Check for installed software.

Options:
  [ --tools | -t ]         Specify tools yaml file location
  [ --tool-pack | -tp ]   Specify tool pack you want to install
  [ --use-repo-tools ]     Use the default tools.yaml in the main repo
  [ --accept | -y ]        Auto install unmet pre-reqs. No prompts
  [ --help | -h ]          Print this help message

Usage:
  ./run.sh --tools /tmp/tools_file.yaml --tool-pack ai-workstation --accept
  -- or --
  ./run.sh --use-repo-tools --tool-pack ai-workstation
EOM
)

req_met=$(cat << EOM
${green}All requirements met!${reset}
EOM
)

main() {
  local failed_software=() install="" tools=()
  current_version=0
  PATH=$PATH:/usr/local/bin
  eval $(parse_yaml "${tools_yaml}")
  get_tool_pack tools_to_install
  check_tools failed_software "${tools_to_install[@]}"
  if [[ ${failed_software[@]} == "" ]]
  then
    printf "${req_met}\n"
    exit 0
  fi
  ask_to_install install
  [[ "${install}" == "y" ]] && install_tools "${failed_software[@]}" || exit 0
  main
}

[[ $# -eq 0 ]] && \
  printf "Missing options!\n\n${usage}\n" && \
  exit 1
while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    "--tools"|"-t")
      tools_yaml=$2
      shift
      shift
      ;;
    "--tool-pack"|"-tp")
      tool_pack=$2
      shift
      shift
      ;;
    "--use-repo-tools")
      default_tools
      shift
      ;;
    "--accept"|"-y")
      accept=0
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
is_elevated
[[ $? == 1 ]] && \
  echo "${red}Please re-run with elevated privileges${reset}" && \
  exit $E_NOTROOT
main
