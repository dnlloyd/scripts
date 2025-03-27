src_net_num=`ifconfig | grep "inet 192.168." | awk '{print $2}' | awk -F'.' '{print $3}'`
dest_ip=$1
dest_net_num=`echo $dest_ip | awk -F'.' '{print $3}'`

case $src_net_num in
  "99")
    src_net="Secure"  
    ;;
  "10")
    src_net="Home"
    ;;
  "20")
    src_net="Gaming"
    ;;
  "0")
    src_net="Management"
    ;;
  "100")
    src_net="Public"
    ;;
  *)
    echo "Unable to determine source network"
    ;;
esac

case $dest_net_num in
  "99")
    dest_net="Secure"
    ;;
  "10")
    dest_net="Home"
    ;;
  "20")
    dest_net="Gaming"
    ;;
  "0")
    dest_net="Management"
    ;;
  "100")
    dest_net="Public"
    ;;
  *)
    echo "Unable to determine destination network"
    ;;
esac


echo "${src_net} --> ${dest_net}"
echo "Attempting to connect to ${dest_ip}:${2}"

echo "from ${src_net}" | nc -v -G3 $1 $2

