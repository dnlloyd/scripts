while true
do 
  date
  kubectl get nodes -o wide
  echo "---"
  sleep 5
done