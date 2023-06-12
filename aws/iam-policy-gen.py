import boto3
import json
from datetime import datetime
import time
import logging

accessanalyzer_client = boto3.client('accessanalyzer')
iam_client = boto3.client('iam')

cloud_trail_arn = 'arn:aws:cloudtrail:us-east-1:166865586247:trail/cloud-trail-parent-account'
access_analyzer_role_arn = 'arn:aws:iam::166865586247:role/service-role/AccessAnalyzerMonitorServiceRole_HSM1502355'
# Quotas on Access analyzer: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-quotas.html
# Policy generations per day: 50
max_roles_analyze = 2
logging.basicConfig(level=logging.INFO)
output_dir = './tmp'

def get_all_roles(client):
  roles = []
  response = client.list_roles(MaxItems=max_roles_analyze)

  for role in response['Roles']:
    roles.append({
      "role_name": role["RoleName"],
      "role_arn": role["Arn"]
    })

  return roles

def get_role_attached_policies(role, client):
  attached_policies = []

  response = client.list_attached_role_policies(
    RoleName=role,
    # PathPrefix='string',
    # Marker='string',
    # MaxItems=123
  )

  for attached_policy in response['AttachedPolicies']:
    attached_policies.append(attached_policy)

  return attached_policies

def get_role_inline_policies(role, client):
  inline_policies = []

  response = client.list_role_policies(
    RoleName=role,
    # Marker='string',
    # MaxItems=123
  )

  inline_policy_names = response['PolicyNames']

  for inline_policy_name in inline_policy_names:
    policy_role_map = {
      'PolicyName': inline_policy_name, 
      'Role': role
    }

    inline_policies.append(policy_role_map)

  return inline_policies

def get_role_actions(attached_policies, client):
  actions = []

def get_policy_gen_response(client, job_id):
  response = client.get_generated_policy(
    jobId=job_id,
    includeResourcePlaceholders=False,
    includeServiceLevelTemplate=False
  )

  return response

def get_used_actions(response):
  actions = []
  for policy_dict in response['generatedPolicyResult']['generatedPolicies']:
    policy = json.loads(policy_dict['policy'])
    for statement in policy['Statement']:
      if statement['Effect'] == 'Allow':
        for action in statement['Action']:
          actions.append(action)
  
  return actions

def get_generated_policies(response):
  policies = []

  for policy_dict in response['generatedPolicyResult']['generatedPolicies']:
    policy = json.loads(policy_dict['policy'])
    policy_json = json.dumps(policy, indent=2)
    policies.append(policy_json)
    print('')

    return policies

###### Main ######
roles = get_all_roles(iam_client)

###### Test stubs ######
# roles return test stub with history
roles = [
  {
    "role_name": "IamAuditTestRole",
    "role_arn": "arn:aws:iam::166865586247:role/IamAuditTestRole"
  },
  {
    "role_name": "AWSServiceRoleForAmazonEKS",
    "role_arn": "arn:aws:iam::166865586247:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS"
  }
]

print('Analyzing the following roles:')
for role in roles:
  print(role["role_arn"])

  print('\nAttached Policies')
  attached_policies = get_role_attached_policies(role["role_name"], iam_client)
  for policy in attached_policies:
    print(policy)
  print('')

  # TODO: get actions from policy for attached policies

  print('\nInline Policies')
  inline_policies = get_role_inline_policies(role["role_name"], iam_client)
  for policy_name in inline_policies:
    print(policy_name)
  print('')

  # TODO: get actions from policy document for inline policies
  #   for inline_policy in inline_policies:
  #     response = client.get_role_policy(
  #       RoleName=role,
  #       PolicyName=inline_policy
  #   )

# TODO: Re-enable
# for policy in attached_policies:
#   print(policy)

# for role in roles:
#   print('')
#   print(f'Analyzing role: {role["role_arn"]}')
#   print('Hold tight, this could take a hot minute...\n')
#   policy_gen_response = accessanalyzer_client.start_policy_generation(
#     policyGenerationDetails={
#       'principalArn': role["role_arn"]
#     },
#     cloudTrailDetails={
#       'trails': [
#           {
#             'cloudTrailArn': cloud_trail_arn,
#             'allRegions': True
#           },
#         ],
#       'accessRole': access_analyzer_role_arn,
#       'startTime': datetime(2023, 6, 8)
#     }
#   )

#   policy_gen_job_id = policy_gen_response['jobId']
#   logging.debug(f'Job ID: {policy_gen_job_id}')

#   get_policy_response = get_policy_gen_response(accessanalyzer_client, policy_gen_job_id)
#   status = get_policy_response['jobDetails']['status']

#   while status != 'SUCCEEDED':
#     logging.debug(f'Job {policy_gen_job_id} status is not \'SUCCEEDED\', sleeping for 30s...')
#     logging.debug(f'job status was {status}')
#     time.sleep(30)

#     logging.debug('trying again...')
#     get_policy_response = get_policy_gen_response(accessanalyzer_client, policy_gen_job_id)
#     status = get_policy_response['jobDetails']['status']

#   if status == 'SUCCEEDED':
#     logging.debug(f'Job {policy_gen_job_id} was successful, getting actions used by role: \n{role["role_arn"]}')
#     used_actions = get_used_actions(get_policy_response)
#     print(role["role_arn"])
#     print('----------------------------------------------')

#     if used_actions != None:      
#       outfile_name = f'{output_dir}/{role["role_name"]}-used-actions.txt'
#       logging.debug(f'Writing used actions to {outfile_name} in current directory')

#       with open(outfile_name, "w") as outfile:
#         for used_action in used_actions:
#           print(used_action)
#           outfile.write(f'{used_action}\n')

#     generated_policies = get_generated_policies(get_policy_response)
#     if generated_policies != None:
#       for index, policy in enumerate(generated_policies):
#         outfile_name = f'{output_dir}/{role["role_name"]}-policy-{index + 1 }.json'
#         logging.debug(f'Writing policy to {outfile_name} in current directory')
#         with open(outfile_name, "w") as outfile:
#           outfile.write(policy)
#     else:
#       print('no history for role')

#   else:
#     print(f'Job {policy_gen_job_id} was NOT successful, I\'m giving up')
#     print(f'Final status was: {status}')
