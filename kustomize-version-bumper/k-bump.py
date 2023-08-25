import os
import re
import logging
import subprocess
import git
import requests
import fileinput
from getpass import getpass
import json
import semantic_version
import sys
import time

inputs_file = open(sys.argv[1])
inputs = json.load(inputs_file)

## Inputs: global ####
logging.basicConfig(level=logging.INFO)
show_diffs = True
local_git_dir = inputs['local_git_dir']  # e.g. '/Users/dan/github/MyGithubOrg'

## Inputs: framework Kustomize base ####
# This assumes the repos for all applications (below) have previously been cloned locally (to local_git_dir)
applications_to_bump_framework_base = inputs['applications_to_bump_framework_base'] # e.g. ['foo', 'bar]
framework_base = inputs['framework_base'] # e.g. 'Tomcat'
framework_k8s_path = inputs['framework_k8s_path']  # e.g. '/deployment/k8s-manifests'
framework_base_tag_prefix = inputs['framework_base_tag_prefix']  # e.g. 'tomcat-'
framework_base_repo = local_git_dir + "/" + framework_base  # e.g. '/Users/dan/github/MyGithub_org/Tomcat'

## Inputs: application Kustomize base ####
environment = inputs['environment'] # e.g. prod
# This assumes the repos for all applications (below) have previously been cloned locally (to local_git_dir)
applications_to_bump_application_base = inputs['applications_to_bump_application_base'] # e.g. ['foo', 'bar]
deployment_repo_name = inputs['deployment_repo_name'] # e.g. 'MyDeployments'
deployment_repo = local_git_dir + '/' + deployment_repo_name # e.g. '/Users/dan/github/MyGithubOrg/MyDeployments'
deployment_repo_env_path = deployment_repo + '/k8s/' + environment # e.g. '/Users/dan/github/MyGithubOrg/MyDeployments/k8s/prod'

jira_number = input('Enter Jira # (Will be used in branch names and PRs): ')

def get_latest_tag(repo, tag_prefix):
  os.chdir(repo)
  os.system('git fetch --quiet --all --tags')

  git_repo = git.cmd.Git(repo)
  t_list = git_repo.tag("--list")
  echo = subprocess.Popen(['echo', t_list], stdout=subprocess.PIPE)
  egrep_tag = subprocess.Popen(['egrep', f'^{tag_prefix}v[0-9]+\.[0-9]+\.[0-9]+'], stdin=echo.stdout, stdout=subprocess.PIPE)
  sort_by_version = subprocess.Popen(('sort', '-V'), stdin=egrep_tag.stdout, stdout=subprocess.PIPE)
  tail_latest = subprocess.Popen(('tail', '-n 1'), stdin=sort_by_version.stdout, stdout=subprocess.PIPE)
  output = tail_latest.communicate()[0]
  latest_tag = output.decode().strip()

  if latest_tag == "":
    latest_tag = f'{tag_prefix}v0.1.0'

  return latest_tag


def get_default_branch(application):
  os.chdir(local_git_dir + "/" + application)
  git_app_repo = git.cmd.Git(local_git_dir + "/" + application)
  default_branch_long = git_app_repo.symbolic_ref("refs/remotes/origin/HEAD")
  default_branch = default_branch_long.split("/")[3]

  return default_branch


def prep_git_branches(applications):
  for application in applications:
    os.chdir(local_git_dir + "/" + application)
    git_app_repo = git.cmd.Git(local_git_dir + "/" + application)
    default_branch = get_default_branch(application)

    print(f'Checking out {default_branch} branch for {application}')
    git_app_repo.checkout(default_branch)
    os.system(f'git pull --quiet origin {default_branch}')


def update_apps_base_versions(latest_tag):
  base_tag_pattern = re.compile(f'.*{framework_base_tag_prefix}v[0-9]+\.[0-9]+\.[0-9]+')
  apps_to_update = set()

  for application in applications_to_bump_framework_base:
    app_file_path = local_git_dir + "/" + application + framework_k8s_path
    
    for root, dirs, files in os.walk(app_file_path):
      for file in files:
        if file == "kustomization.yaml":
          kustomization_file_path = root + "/" + file

          for line in fileinput.input(kustomization_file_path, inplace=True):
            if base_tag_pattern.match(line.strip()):
              current_tag = line.strip().split("=")[1]
              new_line = line.replace(current_tag, latest_tag)
              print(new_line, end = '')
              apps_to_update.add(application)
              logging.debug(kustomization_file_path)
              logging.debug(line)
            else:
              print(line, end = '')
          
          fileinput.close()
  
  return apps_to_update


def push_git_changes(apps_to_update, latest_tag, pr_number):
  pull_requests = []
  pat = getpass('Github personal access token (PAT):')

  headers = {
    'Authorization': f'Bearer {pat}',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28'
  }

  for application in apps_to_update:
    os.chdir(local_git_dir + "/" + application)

    if show_diffs:
      os.system('git diff --quiet')

    # create new branch
    new_branch = f'{jira_number}-{latest_tag}'
    print(f'Creating new branch {new_branch} for {application}')
    os.system(f'git checkout -b {new_branch}')

    os.system('git add --all')
    os.system(f'git commit -m "{jira_number}: update version to {latest_tag}"')
    print(f'Pushing branch {new_branch} for {application}')
    os.system(f'git push origin {new_branch}')

    default_branch = get_default_branch(application)

    data = {
      'title': f'{jira_number}: update kustomize base to latest version',
      'body': f'Description of changes\nUpdate kustomize base to version {latest_base_tag}\n\nDependencies\n - {pr_number}\n\nTicket\nhttps://buildinglink.atlassian.net/browse/{jira_number}',
      'head': f'{new_branch}',
      'base': f'{default_branch}'
    }
    
    print(f'Making PR for {application}')
    pr_response = requests.post(f'https://api.github.com/repos/BuildingLink/{application}/pulls', headers=headers, data=json.dumps(data))
    time.sleep(2) # was receiving "exceeded a secondary rate limit" errors
    
    if pr_response.status_code != 201:
      print('Error creating PR')
      print(pr_response.status_code)
      print(pr_response.content)
    else:
      json_resp_content = json.loads(pr_response.content.decode())
      pull_requests.append(json_resp_content["html_url"])

  return pull_requests


def bump_minor_version_tag(tag, tag_prefix):
  version = tag.strip(tag_prefix).strip("v")
  sem_version = semantic_version.Version(version)
  new_sem_version = sem_version.next_patch()
  new_tag = tag_prefix + "v" + str(new_sem_version)
  
  return new_tag


def push_tag(application, tag):
  os.chdir(local_git_dir + "/" + application)
  print(f'Creating new tag for {application}: {tag}')
  # print(f'git tag -a {tag} -m {tag}') # os.system(f'git tag -a {tag} -m {tag}')
  os.system(f'git tag -a {tag} -m {tag}')

  # Let's make sure we are tagging the correct commit
  print('Verify the commit to assign tag to:')
  os.system('git --no-pager show -q --pretty=format:%Credcommit:" "%H%nAuthor:" "%an%nDate:" "%cD%nSubject:" "%s%Creset%n HEAD')
  tag_is_correct = input('Is this correct? (y|n)')
  if tag_is_correct == "y":
    print(f'Pushing tag {tag} for {application}')
    # print(f'git push origin {tag}') # os.system(f'git push origin {tag}')
    os.system(f'git push origin {tag}')
  else:
    print(f'!! SKIPPING tag {tag} for {application} !!')


def update_overlays_versions(application, new_tag, tag_prefix):
  base_tag_pattern = re.compile(f'.*{tag_prefix}v[0-9]+\.[0-9]+\.[0-9]+')

  # e.g. /Users/dan/github/BuildingLink/deployments/k8s/development/calendar
  kustomization_file_path = deployment_repo_env_path + "/" + application.lower() + "/" + "kustomization.yaml"

  for line in fileinput.input(kustomization_file_path, inplace=True):
    if base_tag_pattern.match(line.strip()):
      current_tag = line.strip().split("=")[1]
      new_line = line.replace(current_tag, new_tag)
      print(new_line, end = '')
      logging.debug(kustomization_file_path)
      logging.debug(line)
    else:
      print(line, end = '')
  
  fileinput.close()


####################################################
## Main ############################################
####################################################
mode = input('What would you like to do?\n  1. Bump framework bases\n  2. Bump application bases\nSelection: ')

if mode == '1':
  base_pr = input('PR link for ASPNetCore base: ')

  # Get the latest Kustomize base tag
  latest_base_tag = get_latest_tag(framework_base_repo, framework_base_tag_prefix)
  print(f'\nLatest base tag for {framework_base}: {latest_base_tag}\n')

  # Rebase main/master branch for each application
  prep_git_branches(applications_to_bump_framework_base)

  # Find kustomize versions that need to be updated and update them
  # return apps that required version updates
  apps_to_update = update_apps_base_versions(latest_base_tag)
  print('\n---- Applications requiring a base version update ----')
  for application in apps_to_update:
    print(application)
  print('')

  # Create new branches for apps with version updates and make PRs via github REST API
  pull_requests = push_git_changes(apps_to_update, latest_base_tag, base_pr)

  print('\nPull requests')
  for pr in pull_requests:
    print(pr)

if mode == '2':
  # Rebase main/master branch for each application 
  # The new tag will point to the commit of this branch
  prep_git_branches(applications_to_bump_application_base)

  ## Updates to deployments ####################################################
  os.chdir(deployment_repo)
  git_app_repo = git.cmd.Git(deployment_repo)

  # Determine default branch
  default_branch_long = git_app_repo.symbolic_ref("refs/remotes/origin/HEAD")
  default_branch = default_branch_long.split("/")[3]

  # check out and update default branch
  print(f'Checking out {default_branch} branch for deployments repo')
  git_app_repo.checkout(default_branch)
  print(f'Pulling {default_branch} branch for deployments repo')
  os.system(f'git pull --quiet origin {default_branch}')

  # New tags for application bases and update apps to these versions in deployments repo
  for application in applications_to_bump_application_base:
    application_repo = local_git_dir + "/" + application
    tag_prefix = application.lower() + "-"

    # get latest tag and determine new tag version
    latest_tag = get_latest_tag(application_repo, tag_prefix)
    new_tag = bump_minor_version_tag(latest_tag, tag_prefix)
    print(f'{application}: {latest_tag} --> {new_tag}')

    # push new tag
    push_tag(application, new_tag)

    # Find and replace application base versions in overlays
    update_overlays_versions(application, new_tag, tag_prefix)

  os.chdir(deployment_repo)
  # Show diffs of all version updates
  if show_diffs:
    os.system('git diff --quiet')

  # create new branch in deployments repo
  new_branch = f'{jira_number}-app-versions'
  print(f'Creating new branch {new_branch}')
  os.system(f'git checkout -b {new_branch}')

  os.system('git add --all')
  os.system(f'git commit -m "{jira_number}: update application bases"')
  print(f'Pushing branch {new_branch}')
  os.system(f'git push origin {new_branch}')
