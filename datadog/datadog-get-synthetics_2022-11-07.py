# DD_SITE="datadoghq.com" DD_API_KEY="<DD_API_KEY>" DD_APP_KEY="<DD_APP_KEY>" python datadog-get-synthetics.py

from datadog_api_client import ApiClient, Configuration
from datadog_api_client.v1.api.synthetics_api import SyntheticsApi
import re

configuration = Configuration()
with ApiClient(configuration) as api_client:
  api_instance = SyntheticsApi(api_client)
  response = api_instance.list_tests()

alert_names = []

pagerduty_service_keys = {
  "<NAME>": "<KEY>",
  "my-service": "1234567890qwertyuiop"
}

def get_alerts(response, env):
  alerts = {}
  message_pattern_pagerduty = re.compile("^@pagerduty")
  name_pattern = re.compile("^{}".format(env))

  for alert in response['tests']:
    name = alert['name']

    # Only consider prod
    if name_pattern.match(name):
      formatted_name = name.replace("PROD: ", "").lower().replace(" ", "_").replace(".", "_")
      message = alert['message']

      if message_pattern_pagerduty.match(message):
        pagerduty_service = message.rsplit("\n")[0].replace(" ", "")

      slack_service = None
      if "@slack-alerts-prod" in message:
        slack_service = True

      locations = alert['locations']
      min_failure_duration = int(alert['options']['min_failure_duration'])
      period = int(alert['options']['tick_every'])

      if period <= 60:
        period = "EVERY_MINUTE"
      elif period <= 300:
        period = "EVERY_5_MINUTES"
      elif period <= 600:
        period = "EVERY_10_MINUTES"
      elif period <= 900:
        period = "EVERY_15_MINUTES"
      elif period <= 1800:
        period = "EVERY_30_MINUTES"

      try:
        url = alert['config']['request']['url']
      except AttributeError:
        url = None

      try:
        host = alert['config']['request']['host']
      except AttributeError:
        host = None

      try:
        timeout = alert['config']['request']['timeout']
      except AttributeError:
        timeout = None

      try:
        method = str(alert['config']['request']['method'])
      except AttributeError:
        method = None

      try:
        x_token = str(alert['config']['request']['headers']['x-token'])
      except AttributeError:
        x_token = None

      content_type = None
      response_time = None

      for assertion in alert['config']['assertions']:
        if str(assertion['type']) == 'statusCode':
          status_code = int(assertion['target'])
        elif str(assertion['type']) == 'header':
          content_type = assertion['target']
        elif str(assertion['type']) == 'responseTime':
          response_time = assertion['target']

      try:
        renotify_interval = alert['options']['monitor_options']['renotify_interval']
      except AttributeError:
        renotify_interval = None

      alerts[formatted_name] = {
        "name": name,
        "formatted_name": formatted_name,
        "message": message,
        "pagerduty_service": pagerduty_service,
        "slack_service": slack_service,
        "locations": locations,
        "min_failure_duration": min_failure_duration,
        "period": period,
        "url": url,
        "host": host,
        "timeout": timeout,
        "method": method,
        "x_token": x_token,
        "content_type": content_type,
        "response_time": response_time,
        "renotify_interval": renotify_interval
      }
  
  return alerts


def get_pagerduty_groups(alerts, env):
  pagerduty_groups = {}

  for alert, alert_data in alerts.items():
    pagerduty_service = alert_data['pagerduty_service'].replace("@pagerduty-{}_".format(env), "").lower().replace("_", "-")

    if pagerduty_service not in pagerduty_groups:
      pagerduty_groups[pagerduty_service] = [alert_data['formatted_name']]
    else:
      pagerduty_groups[pagerduty_service].append(alert_data['formatted_name'])

  return pagerduty_groups


def print_tf_modules(alerts, pagerduty_groups):
  for pagerduty_svc_name, alert_names in pagerduty_groups.items():
    print(f'module "my_module_{pagerduty_svc_name.replace("-","_")}" {{')
    print('  source = "../../../../../providers/newrelic/modules/bundle"')
    print(f'  name   = "my-client-${{var.environment}}-{pagerduty_svc_name}"')

    if pagerduty_svc_name in pagerduty_service_keys:
      print(f'  service_key = "{pagerduty_service_keys[pagerduty_svc_name]}"')
    else:
      raise Exception("PagerDuty key not found for this service")

    print('')
    print('  custom_alerting = {}')
    print('')
    print('  custom_synthetics_monitors_scripted_api = {')

    for alert_name in alert_names: 
      print(f'    {alert_name} = {{')
      print(f'      locations_public = [')
      print(f'        "US_WEST_1",')
      print(f'        "US_WEST_2",')
      print(f'        "US_EAST_1",')
      print(f'      ]')
      print('')
      print(f'      locations_private           = []')
      print(f'      script                      = ""')
      print(f'      description                 = ""')

      if alerts[alert_name]['x_token'] == None:
        print(f'      script_raw                  = templatefile("./synthetic-check-api.js.tftpl", {{ url = "{alerts[alert_name]["url"]}", token_stanza = "" }})')
      else:
        print(f'      script_raw                  = templatefile("./synthetic-check-api.js.tftpl", {{ url = "{alerts[alert_name]["url"]}", token_stanza = "\'x-token\': \'${{var.api_token}}\',"}})')

      print(f'      critical_threshold          = 0.95')
      print(f'      critical_threshold_duration = {alerts[alert_name]["min_failure_duration"]}')
      print(f'      default_alert               = true')
      print(f'      period                      = "{alerts[alert_name]["period"]}"')
      print('    }')
      print('')
    print('  }')
    print('}')
    print('')


env_name = "PROD"
prod_alerts = get_alerts(response, env_name)
prod_pagerduty_groups = get_pagerduty_groups(prod_alerts, env_name)
print_tf_modules(prod_alerts, prod_pagerduty_groups)
