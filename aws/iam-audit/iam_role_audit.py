import boto3
import re
import logging
import json
import os
import athena_query

# General inputs
logging.basicConfig(level=logging.INFO)
use_role_test_stubs = True

# IAM inputs
iam_client = boto3.client('iam')
exclude_service_roles = True
service_role_path_pattern = re.compile("(.*\/aws-service-role\/.*|.*\/service-role\/.*)")
all_roles_path_prefix = '/aws-reserved/sso.amazonaws.com'
roles = []

# Athena inputs
# Note: Athena requires separate credentials if in a separate account
# export AWS_ACCESS_KEY_ID_ATHENA="XXX"
# export AWS_SECRET_ACCESS_KEY_ATHENA="XXX"
# export AWS_SESSION_TOKEN_ATHENA="XXX"
# export AWS_REGION_ATHENA=us-east-1


athena_session = boto3.Session(
  aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID_ATHENA'],
  aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY_ATHENA'],
  aws_session_token=os.environ['AWS_SESSION_TOKEN_ATHENA'],
  region_name=os.environ['AWS_REGION_ATHENA']
)

s3_client = athena_session.client('s3')

query_result_header_pattern = re.compile("^\"Action")
output_dir = './audit-files'
athena_query_params = {
  'account': '123456789012',
  'region': 'us-east-1',
  'database_fq': 'awsdatacatalog.accounts.cloudtrail_logs_all',
  'database': 'all_accounts',
  'bucket': 'athena-query-results-us-east-1',
  'path': '',
  'start_query_date_pattern': '2023/06/%'
}

def get_all_roles(client):
  response = client.list_roles(PathPrefix=all_roles_path_prefix, MaxItems=50)
  update_roles(response['Roles'])

  while response['IsTruncated']:
    response = client.list_roles(PathPrefix=all_roles_path_prefix, MaxItems=50, Marker=response['Marker'])
    update_roles(response['Roles'])

def update_roles(list_roles_response):
  for role in list_roles_response:
    if exclude_service_roles:
      if not service_role_path_pattern.match(role["Arn"]):
        roles.append({
          "role_name": role["RoleName"],
          "role_arn": role["Arn"]
        })
    else:
      roles.append({
          "role_name": role["RoleName"],
          "role_arn": role["Arn"]
        })

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

def print_roles(roles, format):
  count = 1
  for role in roles:
    if format == 'arns':
      print(f'{count}: {role["role_arn"]}')
      count += 1
    elif format == 'names':
      print(f'{count}: {role["role_name"]}')
      count += 1

def get_role_attached_policies(role, client):
  attached_policies = []
  response = client.list_attached_role_policies(RoleName=role)

  if response['IsTruncated']:
    print('WARNING: not all role attached policies included')

  for attached_policy in response['AttachedPolicies']:
    attached_policies.append(attached_policy)

  return attached_policies

def get_role_inline_policies(role, client):
  inline_policies = []

  response = client.list_role_policies(RoleName=role)
  inline_policy_names = response['PolicyNames']

  if response['IsTruncated']:
    print('WARNING: not all role attached policies included')

  for inline_policy_name in inline_policy_names:
    policy_role_map = {
      'PolicyName': inline_policy_name, 
      'Role': role
    }

    inline_policies.append(policy_role_map)

  return inline_policies

def get_policy_version(policy_arn, client):
  response = client.get_policy(PolicyArn=policy_arn)

  policy_version = response['Policy']['DefaultVersionId']
  return policy_version

def get_policy_doc_attached(policy_arn, version, client):
  response = client.get_policy_version(
    PolicyArn=policy_arn,
    VersionId=version
  )

  policy_document = response['PolicyVersion']['Document']
  return policy_document

def get_policy_document_inline(role_name, policy_name, client):
  response = client.get_role_policy(
    RoleName=role_name,
    PolicyName=policy_name
  )

  policy_document = response['PolicyDocument']
  return policy_document

def get_policy_actions(policy_document):
  actions = set()
  not_actions = set()

  for statement in policy_document['Statement']:
    if statement['Effect'] == 'Allow':
      if 'Action' in statement.keys():
        if isinstance(statement['Action'], list):
          for action in statement['Action']:
            logging.debug(f'+ {action}')
            actions.add(action)
        else:
          logging.debug(f'+ {statement["Action"]}')
          actions.add(statement['Action'])
      else:
        # NotActions
        logging.debug('XXX-NOTACTION')
        if isinstance(statement['Action'], list):
          for action in statement['Action']:
            logging.debug(f'notaction {action}')
            not_actions.add(action)
        else:
          logging.debug(f'notaction {statement["Action"]}')
          not_actions.add(statement['Action'])
    elif statement['Effect'] == 'Deny':
      if 'Action' in statement.keys():
        if isinstance(statement['Action'], list):
          for action in statement['Action']:
            logging.debug(f'- {action}')
            actions.discard(action)
        else:
          logging.debug(f'- {statement["Action"]}')
          actions.discard(statement['Action'])

  return actions


####################### MAIN #######################

if use_role_test_stubs:
  # Role test stubs
  roles = [
    {
      'role_name': 'AWSReservedSSO_Admin', 
      'role_arn': 'arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_Admin'
    },
    {
      'role_name': 'AWSReservedSSO_Developer', 
      'role_arn': 'arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_Developer'
    }
  ]
else:
  print('Retrieving all roles')
  if exclude_service_roles:
    print('  - Excluding service roles')

  get_all_roles(iam_client)

# print_roles(roles, 'arns')

for index, role in enumerate(roles):
  print(f'Aggregating actions from inline and attached policies for role {role["role_name"]}')
  actions = set()

  role_attached_policies = get_role_attached_policies(role['role_name'], iam_client)
  # print(f'Attached policies:\n------------------')
  for policy in role_attached_policies:
    policy_version = get_policy_version(policy['PolicyArn'], iam_client)
    policy_document_attached = get_policy_doc_attached(policy['PolicyArn'], policy_version, iam_client)
    policy_attached_actions = get_policy_actions(policy_document_attached)
    # print(f'------ {policy["PolicyName"]}')
    # print(policy_attached_actions)
    # print('')
    actions = actions.union(policy_attached_actions)
  
  role_inline_policies = get_role_inline_policies(role['role_name'], iam_client)
  # print(f'Inline policies:\n----------------')
  for policy in role_inline_policies:
    policy_document_inline = get_policy_document_inline(role['role_name'], policy["PolicyName"], iam_client)
    policy_inline_actions = get_policy_actions(policy_document_inline)
    # print(f'------ {policy["PolicyName"]}')
    # print(policy_inline_actions)
    # print('')
    actions = actions.union(policy_inline_actions)

  roles[index]['actions'] = actions

all_actions_file = open("all-actions.json")
all_actions = json.load(all_actions_file)

for role in roles:
  print(f'Expanding wildcard actions for role: {role["role_name"]}')
  wildcard_actions_to_remove = set()
  full_actions_to_add = set()
  for action in role["actions"]:
    if '*' in action:
      pattern = re.compile(action.replace("*", ".*"))

      for full_action in all_actions:
        if pattern.match(full_action):
          full_actions_to_add.add(full_action)

      wildcard_actions_to_remove.add(action)
  
  role["actions"].difference_update(wildcard_actions_to_remove)
  role['actions'].update(full_actions_to_add)
  role['actions'] = list(role['actions'])
  role['actions'].sort()

  defined_actions_file = open(f'{output_dir}/{role["role_name"]}-defined-actions.txt', "w")
  for action in role["actions"]:
    defined_actions_file.write(f'{action}\n')
  
  defined_actions_file.close()

  role_query = f"""
    SELECT DISTINCT concat(split_part(eventsource, '.', 1), ':', eventname) as Action
    FROM {athena_query_params['database_fq']}
    WHERE account IN ('{athena_query_params['account']}')
      AND useridentity.sessioncontext.sessionissuer.type = 'Role'
      AND timestamp LIKE '{athena_query_params['start_query_date_pattern']}'
      AND useridentity.sessioncontext.sessionissuer.username = '{role['role_name']}'
    ORDER BY Action
  """

  print(f'Auditing API calls made by role {role["role_name"]} via Athena/CloudTrail')
  print(f'  - Audit start date: {athena_query_params["start_query_date_pattern"]}')
  location, data = athena_query.query(athena_session, athena_query_params, role_query)

  print(f'Downloading query result from: {location}')
  bucket_name = location.split("/")[2]
  bucket_object = location.split("/")[3]
  query_results_file_name = f'{output_dir}/{role["role_name"]}.csv'

  s3_client.download_file(bucket_name, bucket_object, query_results_file_name)
  print(f'Query result saved to {query_results_file_name}\n')

  used_actions = set()
  query_results_file = open(query_results_file_name, "r")

  for line in query_results_file:
    if query_result_header_pattern.match(line):
      continue

    used_actions.add(line.rstrip().strip('\"'))

  role["used_actions"] = used_actions

  os.remove(query_results_file_name)

  used_actions_file = open(f'{output_dir}/{role["role_name"]}-used-actions.txt', "w")
  for action in role["used_actions"]:
    used_actions_file.write(f'{action}\n')
  
  used_actions_file.close()

print(f'\n***************************** Used vs defined for ({athena_query_params["start_query_date_pattern"]})*****************************')
for role in roles:
  print(role['role_name'])
  print(f'Defined action count: {len(role["actions"])}')
  print(f'Used action count: {len(role["used_actions"])}\n')

# TODO
# - automate beyond compare reports
# - automate get all IAM actions
