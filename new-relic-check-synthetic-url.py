# usage: python new-relic-check-synthetic-url.py <My API Key>

from requests.auth import HTTPBasicAuth
import requests
import sys
import re
import base64

token = sys.argv[1]
headers = {'Api-Key': f'{token}'}
params = {'limit': 100}
pattern = re.compile("^prod-")
api_endpoint = 'https://synthetics.newrelic.com/synthetics/api/v3/monitors'

message_pattern_uri = re.compile("uri:.*")

url_mon = api_endpoint
while True:
  response = requests.get(url_mon, headers=headers, params=params)

  for monitor in response.json()['monitors']:
    if pattern.match(monitor['name']):
      print(monitor['name'])

      script_response = requests.get(f"https://synthetics.newrelic.com/synthetics/api/v3/monitors/{monitor['id']}/script", headers=headers, params=params)
      script_base64 = script_response.json()['scriptText']
      script = base64.b64decode(script_base64)

      result = message_pattern_uri.search(script.decode('utf-8'))
      if result:
        print(result.group(0))

      print('')

  try:
    url_mon = response.links['next']['url']
  except:
    break
