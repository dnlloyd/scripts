#!/usr/bin/env python3

# usage: python pagerduty.py <My API Key>

from requests.auth import HTTPBasicAuth
import requests
import sys

token = sys.argv[1]

headers = {
  'Authorization': f'Token token={token}',
  'Accept': 'application/vnd.pagerduty+json;version=2',
  'Content-Type': 'application/json'
}

params = {'limit': 100}

def get_services(headers, params):
  services = []
  url = 'https://api.pagerduty.com/services'
  response = requests.get(url, headers=headers, params=params)

  # print(response.json()['more'])

  for service in response.json()['services']:
    services.append(service['name'])
    # print(service['name'])

  return services


def print_escalation_policies(headers):
  url = 'https://api.pagerduty.com/escalation_policies'
  response = requests.get(url, headers=headers)

  for policy in response.json()['escalation_policies']:
    print('**************************************')
    print(policy['name'])
    print('**************************************')

    print('Rules:')
    print('-------------')
    for rule in policy['escalation_rules']:
      print(f'Delay: {rule["escalation_delay_in_minutes"]}')

      print('Targets:')
      for target in rule['targets']:
        print(f'  - {target["summary"]} ({target["id"]})')
      
    print('')

    print('Services')
    for service in policy['services']:
      print(f'  - {service["summary"]}')
  
    print('')
  

def print_users(headers):
  url = 'https://api.pagerduty.com/users'
  response = requests.get(url, headers=headers)

  for user in response.json()['users']:
    print(f'{user["name"]} ({user["id"]})')
    print(user["email"])
    print(user["role"])
    print('')


def print_priorities(headers):
  url = 'https://api.pagerduty.com/priorities'
  response = requests.get(url, headers=headers)

  for priority in response.json()['priorities']:
    print(priority["summary"])
    print('')


def gen_tf(services):
  file = open('./pagerduty.tf', "w")
  file_outputs = open('./outputs.tf', "w")
  file.write(top + '\n\n')

  for service in services:
    if service in ['Aggregate_service', 'dan-fog-test']:
      continue

    name_module = service.replace("PROD: ", "").replace("CLIENT-NAME ", "").replace("CLIENT-NAME ", "").lower().replace(" ", "_")
    name_formatted = service.replace("PROD: ", "").replace("CLIENT-NAME ", "").replace("CLIENT-NAME ", "")
    name_formatted = "CLIENT-NAME " + name_formatted
    name_formatted = name_formatted.title()
    name_service = "Prod: " + name_formatted

    file.write(f'module "{name_module}" {{\n')
    file.write('  source                    = "../modules/new-relic"\n')
    file.write(f'  name                      = "{name_formatted}"\n')
    file.write(f'  description               = "{name_formatted}"\n')
    file.write(middle + '\n')
    file.write(f'      name = "{name_service}"')
    file.write(bottom + '\n')

    file_outputs.write(f'output "{name_module}" {{\n')
    file_outputs.write('  value = {\n')
    file_outputs.write(f'    team                = module.{name_module}.team\n')
    file_outputs.write(f'    members             = module.{name_module}.members\n')
    file_outputs.write(f'    escalation_policies = module.{name_module}.escalation_policies\n')
    file_outputs.write(f'    schedules           = module.{name_module}.schedules\n')
    file_outputs.write(f'    services            = module.{name_module}.services\n')
    file_outputs.write('  }\n')
    file_outputs.write('}\n\n')

  file.close()
  file_outputs.close()


top = """locals {
REMOVED
"""

middle = """
REMOVED
"""

bottom = """
REMOVED
"""

services = get_services(headers, params)
gen_tf(services)

for service in services:
  if service in ['MY-FAKE_service', 'dan-fog-test']:
    continue

  fm_name = service.replace("PROD: ", "").replace("CLIENT-NAME ", "").replace("CLIENT-NAME ", "")
  fm_name = "CLIENT-NAME " + fm_name
  fm_name = fm_name.title()

  code_name = fm_name.lower().replace(" ", "_")

  print(f'    {code_name} = {{')
  print(f'      name = "{fm_name}"')
  print('    },')

# print(services)
# print_users(headers)
# print_escalation_policies(headers)
# print_priorities(headers)
