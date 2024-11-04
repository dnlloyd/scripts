"""Lookup name from student ID in Canvas API"""
import json
import os
import sys

import requests
from colorama import init, Fore, Style

init()

token = os.environ['CANVAS_TOKEN']
canvas_course_id = os.environ['CANVAS_COURSE_ID']
headers = {'Authorization': f'Bearer {token}'}
arg = sys.argv[1]

response = requests.get(f'https://mcckc.instructure.com/api/v1/courses/{canvas_course_id}/users?per_page=50', headers=headers, timeout=10)
response.raise_for_status()
student_response = json.loads(response.content.decode())

def student_lookup(students):
    """Lookup individual student"""
    for student in students:
        if student['login_id'] ==  arg.upper():
            print(student['name'])
            print(student['email'])


def lookup_all(students):
    """List all student names and IDs"""
    for student in students:
        print(student['login_id'] + " " + Fore.CYAN + student['name'] + Style.RESET_ALL + " " + student['email'])


if arg == "all":
    lookup_all(student_response)
else:
    student_lookup(student_response)
