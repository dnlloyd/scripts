#!/bin/bash

NOTES_PATH="/Users/dl014945/Notes"

function join_by { local d=$1; shift; local f=$1; shift; printf %s "$f" "${@/#/$d}"; }

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

  case $key in
    -r|--recursive)
    RECURSIVE="true"
    shift # past argument
    ;;
    *)    # Search string
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
  esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters

find_search_string=""
grep_search_string=""

for i in "${POSITIONAL[@]}"
do
  find_search_string+="-iname \"*${i}*\" "
  # grep_search_string+="${i}"
done
find_cmd="find ${NOTES_PATH}/ ${find_search_string}"

echo '------- File names -------'
eval $find_cmd
echo ''

grep_search_string="${POSITIONAL[*]}"
grep_search_string="${grep_search_string//${IFS:0:1}/|}"

grep_cmd="egrep -isl \"${grep_search_string}\" ${NOTES_PATH}"

echo '------- File contents -------'
eval "${grep_cmd}/*"

# echo '------- File contents -------'
# if [[ $RECURSIVE = "true" ]]
#   then
#     grep -Risl $SEARCH_STR $NOTES_PATH
#   else
#     grep -isl $SEARCH_STR $NOTES_PATH/*
# fi
