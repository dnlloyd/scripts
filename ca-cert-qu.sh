# Usage: ./ca-certs <Search Sting>

CACERTS_PATH=`find "${JAVA_HOME}" -name cacerts`

cp /dev/null cas.out

echo "" | keytool -list -keystore "${CACERTS_PATH}" |grep -i $1 > cacerts.out

IFS_OLD=$IFS
IFS=$'\n'

for alias in $( cat cacerts.out | awk -F',' '{print $1}' )
do
  # echo $alias
  echo "" | keytool -v -list -keystore $CACERTS_PATH -alias "${alias}" | egrep "Alias name:|Owner|Serial number:|SHA256:" >> cas.out
done

IFS=$IFS_OLD

cat cas.out
