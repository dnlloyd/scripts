# Checks syntax of ruby (.rb) and JSON (.json) files for 
#!/bin/bash
echo "Checking ruby files in this directory:"
echo "--------------------------------------"
for i in $( find . -name "*.rb" )
do	
  ruby -c $i
done

echo ""
echo "Checking JSON files in this directory:"
echo "--------------------------------------"
find . -name '*.json' | xargs -n1 ruby -e "puts ARGV[0];require 'json';file=IO.read(ARGV[0]);JSON.parse(file)"
