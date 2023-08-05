#!/usr/bin/env python3
# Usage: python new-relic-change-tracker.py <API Key>

from requests.auth import HTTPBasicAuth
import requests
import json
import sys

api_key = sys.argv[1]
headers = {'API-Key': f'{api_key}'}
entity_guid = '123456789012345678901234567890'
version = '0.0.6'
user = 'Daniel Lloyd'
description = 'Test change tracker'
commit = '123456789012345678901234567890'
changelog = 'tracker test 06'

nerd_graph_query = f"""
  mutation {{
    changeTrackingCreateDeployment(
      deployment: {{
        version: "{version}"
        user: "{user}"
        entityGuid: "{entity_guid}"
        description: "{description}"
        deploymentType: BASIC
        deepLink: "https://www.daniel-lloyd.net/"
        commit: "{commit}"
        changelog: "{changelog}"
      }}
    ) {{
      changelog
      commit
      deepLink
      deploymentId
      deploymentType
      description
      entityGuid
      user
      version
    }}
  }}
"""

response = requests.post('https://api.newrelic.com/graphql', 
  headers = {'API-Key': f'{api_key}'}, 
  json = {"query": nerd_graph_query}
)

if response.status_code == 200: 
  resp_content = json.loads(response.content)
  print(resp_content)
else:
  raise Exception(f'API call failed with a {response.status_code}.')
