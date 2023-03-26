deployment_files=()
namespaces=()
images=()

for file in $( grep -Rs "image:" . | grep -v deployment-tunnel.yaml | sort | awk -F": " '{print $1}' )
do
  deployment_files+=($file)
done

# echo ${deployment_files[@]}

for deployment_file in  ${deployment_files[@]}
do
  image=`grep "image:" $deployment_file | awk '{print $2}'`
  namespace=`grep "namespace:" $deployment_file | awk '{print $2}'`

  echo $namespace $image $deployment_file
done
