"""GitHub setup for MCC CSIS-119"""
import requests
import os
import json


GITHUB_ORG = 'MCC-CSIS-119'
CANVAS_COURSE_ID = '16666'

github_pat = os.environ['GITHUB_PAT']
canvas_token = os.environ['CANVAS_TOKEN']

canvas_headers = {'Authorization': f'Bearer {canvas_token}'}

github_header = {
    'Authorization': f"Bearer {github_pat}",
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28'
}

github_url = f"https://api.github.com/orgs/{GITHUB_ORG}/repos"



def create_repo(repo_name, student_name, class_name):
    github_data = {
        "name": repo_name,
        "description": f"{repo_name}'s repo for {class_name}",
        "private": True,
        "has_issues": False,
        "has_projects": False,
        "has_wiki": False,
        "auto_init": True,
        "gitignore_template": 'Python'
    }

    response = requests.post(github_url, headers=github_header, data=github_data)
    response.raise_for_status()

    return response

def fetch_students(course_id):
    response = requests.get(f'https://mcckc.instructure.com/api/v1/courses/{canvas_course_id}/users?per_page=50', headers=headers, timeout=10)
    response.raise_for_status()
    students = json.loads(response.content.decode())

    return students

fetch_students(CANVAS_COURSE_ID)

# TODO: 
# 1) Grant users "Write" access to repo
# 2) Create initial grading branch

