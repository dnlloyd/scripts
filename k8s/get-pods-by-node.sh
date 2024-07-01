RED='\033[1;31m'
GREEN='\033[0;32m'
NC='\033[0m'

old_nodes=( $(kubectl get nodes --output='name' | awk -F"/" {'print $2'} ) )

while true
do
  date
  echo "============================================================================================="
  kubectl get nodes
  echo "============================================================================================="

  for node in $( kubectl get nodes | grep ^ip | awk '{print $1}' )
  do
    if [[ ${old_nodes[@]} =~ $node ]]
    then
      echo "--- $node (Old)---"
    else
      echo "${GREEN}--- $node (New)---"
    fi

    kubectl get pods --all-namespaces --field-selector spec.nodeName=$node
    echo "${NC}"
  done

  echo ""
  echo ""
  echo ""

  sleep 10
done
