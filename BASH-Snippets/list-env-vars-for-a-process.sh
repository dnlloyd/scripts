# meta: list all environment variables for a process on separate lines in BASH
# Tested on Alpine

PID=24

while IFS= read -d '' -r line
do
    printf "%q\n" "$line"
done < /proc/$PID/environ
