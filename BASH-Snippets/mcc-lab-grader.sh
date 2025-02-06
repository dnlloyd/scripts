function print_student_users () {
    egrep ".*:x:10[0-9][0-9]:.*:S" /etc/passwd | awk -F":" {'print $1'}
}

for username in $(print_student_users)
do
    echo "Student: $username"
    echo "-------------------------"
    cd /home/$username
    find . -name "name.txt" -exec cat {} +

    echo ""
done
