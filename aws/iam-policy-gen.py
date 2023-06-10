import boto3
import json
from datetime import datetime
import time
import logging

accessanalyzer_client = boto3.client('accessanalyzer')
iam_client = boto3.client('iam')

role_to_analyze = 'arn:aws:iam::166865586247:role/IamAuditTestRole'
cloud_trail_arn = 'arn:aws:cloudtrail:us-east-1:166865586247:trail/cloud-trail-parent-account'
access_analyzer_role_arn = 'arn:aws:iam::166865586247:role/service-role/AccessAnalyzerMonitorServiceRole_HSM1502355'
# Quotas on Access analyzer: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-quotas.html
# Policy generations per day: 50
max_roles_analyze = 5
logging.basicConfig(level=logging.INFO)

def get_all_roles(client):
  role_arns = []
  response = client.list_roles(MaxItems=max_roles_analyze)

  for role in response['Roles']:
    role_arns.append(role['Arn'])
    
  return role_arns

def get_policy_gen_response(client, job_id):
  response = client.get_generated_policy(
    jobId=job_id,
    includeResourcePlaceholders=False,
    includeServiceLevelTemplate=False
  )

  return response

def get_actions(response):
  for policy_dict in response['generatedPolicyResult']['generatedPolicies']:
    policy = json.loads(policy_dict['policy'])
    for statement in policy['Statement']:
      if statement['Effect'] == 'Allow':
        for action in statement['Action']:
          print(action)

def get_generated_roles(response):
  roles = []

  for policy_dict in response['generatedPolicyResult']['generatedPolicies']:

    print('********************* policy_dict *************************')
    print(policy_dict)
    print('***********************************************************')

    policy = json.loads(policy_dict['policy'])
    policy_json = json.dumps(policy, indent=2)
    roles.append(policy_json)
    print('')

    return roles

# get_all_roles = get_generated_roles(iam_client)
role_arns = ['arn:aws:iam::166865586247:role/IamAuditTestRole']

print('Analyzing the following roles:')
for role_arn in role_arns:
  print(role_arn)

for role_arn in role_arns:
  print('')
  print(f'Analyzing role: {role_arn}')
  print('Hold tight, this could take a hot minute...\n')
  policy_gen_response = accessanalyzer_client.start_policy_generation(
    policyGenerationDetails={
      'principalArn': role_arn
    },
    cloudTrailDetails={
      'trails': [
          {
            'cloudTrailArn': cloud_trail_arn,
            'allRegions': True
          },
        ],
      'accessRole': access_analyzer_role_arn,
      'startTime': datetime(2023, 6, 8)
    }
  )

  policy_gen_job_id = policy_gen_response['jobId']
  logging.debug(f'Job ID: {policy_gen_job_id}')

  get_policy_response = get_policy_gen_response(accessanalyzer_client, policy_gen_job_id)
  status = get_policy_response['jobDetails']['status']

  while status != 'SUCCEEDED':
    logging.debug(f'Job {policy_gen_job_id} status is not \'SUCCEEDED\', sleeping for 30s...')
    logging.debug(f'job status was {status}')
    time.sleep(30)

    logging.debug('trying again...')
    get_policy_response = get_policy_gen_response(accessanalyzer_client, policy_gen_job_id)
    status = get_policy_response['jobDetails']['status']

  if status == 'SUCCEEDED':
    logging.debug(f'Job {policy_gen_job_id} was successful, getting actions for role: \n{role_arn}')
    print(role_arn)
    print('----------------------------------------------')
    get_actions(get_policy_response)

    generated_roles = get_generated_roles(get_policy_response)
    for index, role in enumerate(generated_roles):
      outfile_name = f'role-{index + 1 }.json'
      logging.debug(f'Writing role {outfile_name} to current directory')
      with open(outfile_name, "w") as outfile:
        outfile.write(role)

  else:
    print(f'Job {policy_gen_job_id} was NOT successful, I\'m giving up')
    print(f'Final status was: {status}')
