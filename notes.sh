#!/bin/bash

NOTES_PATH="${HOME}/Notes"
DOCS_PATH="${HOME}/Documents/Cerner/github-cerner/ETS-Gamma/ets_gamma_documentation/docs"

# POSITIONAL=()
# while [[ $# -gt 0 ]]
# do
# key="$1"

# case $key in
#     -r|--recursive)
#     RECURSIVE="true"
#     shift # past argument
#     ;;
#     *)    # unknown option
#     POSITIONAL+=("$1") # save it in an array for later
#     shift # past argument
#     ;;
# esac
# done
# set -- "${POSITIONAL[@]}" # restore positional parameters





  # while (( $# > 0 ))
  # do
  #   case "$1" in
  #       -r)      RECURSIVE="true"
  #       ;;
  #   esac
  #   shift 1
  # done


SEARCH_STR=$1
# RECURSIVE=$2

echo '------- File names -------'
find "${NOTES_PATH}/" -iname "*${SEARCH_STR}*"
find "${DOCS_PATH}/" -iname "*${SEARCH_STR}*"
echo ''

echo '------- File contents -------'
# if [[ ! -z $RECURSIVE ]] && [[ $RECURSIVE = "r" ]]
  # then
    grep -Risl $SEARCH_STR $NOTES_PATH
    grep -Risl $SEARCH_STR $DOCS_PATH
#   else
#     grep -isl $SEARCH_STR $NOTES_PATH/*
#     grep -isl $SEARCH_STR $DOCS_PATH/*
# fi

# echo '------- File contents -------'
# if [[ $RECURSIVE = "true" ]]
#   then
#     grep -Risl $SEARCH_STR $NOTES_PATH
#   else
#     grep -isl $SEARCH_STR $NOTES_PATH/*
# fi
