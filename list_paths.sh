OLDIFS="${IFS}"
IFS=:

for path in $PATH
  do echo $path
done

IFS="${OLDIFS}"
