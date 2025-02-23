# declare -i randNum=1234

# for i in $(seq 0 10)
# do
#     # randNum=$(($randNum>>3)^($randNum>>7)^($randNum<<17))
#     num=$((9^1))
#     echo $num
# done
# printf "0x%x" randNum

# echo $randNum
num1=123
num1=$((($num1>>2)^($num1<<17)))
echo $num1
