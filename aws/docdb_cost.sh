ROOT_ACCOUNT="ou-XXXX" # AWS Organizations > AWS accounts > Root > customers
TOTAL_IOPS=0
INSTANCE_UPGRADES=0

for ACCOUNT in $( aws organizations list-children --parent-id $ROOT_ACCOUNT --child-type ACCOUNT --query "Children[*].Id" --output text )
do
  source /Users/dan/github/dnlloyd/My-Mac/scripts/aws/aws_assume_script2.sh OrganizationAccountAccessRole $ACCOUNT

  for CLUSTER in $( aws docdb describe-db-clusters --query "DBClusters[*].DBClusterIdentifier" --output text )
  do
    for IOPS in $(aws cloudwatch get-metric-statistics --metric-name VolumeWriteIOPs --start-time 2022-06-01T00:00:00 --end-time 2022-06-30T23:59:59 --period 2592000 --namespace AWS/DocDB --statistics Sum --dimensions Name=DBClusterIdentifier,Value=${CLUSTER} --query 'Datapoints[*].Sum' --output text --no-cli-pager)
    do
      IOPS=`echo $IOPS | sed 's/\.0//g'`
      echo $IOPS
      TOTAL_IOPS=$((TOTAL_IOPS+$IOPS))
    done
  done

  for DB_INSTANCE in $(aws rds describe-db-instances --query "DBInstances[*].DBInstanceClass" --output text --no-cli-pager --filter "Name=engine,Values=docdb")
  do
    echo $DB_INSTANCE

    case $DB_INSTANCE in
      "db.t3.medium")
        echo "instance requires upgrade"
        INSTANCE_UPGRADES=$(($INSTANCE_UPGRADES+1))
        ;;

      "db.r6g.large")
        echo "no upgrade required!"
        ;;

      *)
        echo "WTF"
        ;;
    esac
  done

  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
done

echo ''
echo "Calculating IOPS based off of June 2022 Total IOPS: ${TOTAL_IOPS}"
IOPS_COST=`echo "$TOTAL_IOPS / 1000000 * .2" | bc -l`
echo "IOPS Volume cost per month: \$${IOPS_COST}"

echo ''
echo "Number of instance upgrades required: ${INSTANCE_UPGRADES}"
INST_CLASS_COSTS=`echo "${INSTANCE_UPGRADES} * 143.28" | bc -l`
echo "Instance class upgrade costs: \$${INST_CLASS_COSTS}"

echo ''
TOTAL_COST_MONTH=`echo $IOPS_COST + $INST_CLASS_COSTS |bc -l`
TOTAL_COST_YEAR=`echo $TOTAL_COST_MONTH * 12 |bc -l`
echo "Total cost per month: ${TOTAL_COST_MONTH}"
echo "Total cost per year: ${TOTAL_COST_YEAR}"
