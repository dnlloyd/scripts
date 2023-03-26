PROCS_NAMES=(
  '/Library/Tanium/TaniumClient/TaniumClient'
  '/Library/Tanium/TaniumClient/Tools/EPI/TaniumEndpointIndex'
  '/Library/Tanium/TaniumClient/Tools/Detect3/TaniumDetectEngine'
)

desired_niceness='19'
# desired_io_priority='7'

pids=()
all_pids=()m

get_pids() {
  for pid in $( pgrep  -f $1 )
  do
    pids+=($pid)
  done
}

# get_threads() {
#   for pid in ${@}
#   do
#     for tid in /proc/$pid/task/*  # This always includes the parent ID as well as the thread ID
#     do
#       all_pids+=(`basename $tid`)
#     done
#   done
# }

set_nice() {
  for pid in ${@}
  do
    # cur_nice=`awk -F')' '{print $2}' /proc/$pid/stat | awk '{print $17}'`
    # cur_io_prio=`ionice -p $pid | awk '{print $3}'`
    # if [ $cur_nice -ne $desired_niceness ] #|| [ $cur_io_prio -ne $desired_io_priority ]
    # then
      renice $desired_niceness -p $pid
      # ionice -c 2 -n $desired_io_priority -p $pid
    # fi
  done
}

for proc_name in ${PROCS_NAMES[@]}
do
  get_pids $proc_name
done

# get_threads "${pids[@]}"
set_nice "${pids[@]}"
