# DD_SITE="datadoghq.com" DD_API_KEY="<DD_API_KEY>" DD_APP_KEY="<DD_APP_KEY>" python datadog-get-synthetics.py
# Migrate DataDog synthetics to Terraform for New Relic

import os
import sys

from datadog_api_client import ApiClient, Configuration
from datadog_api_client.v1.api.synthetics_api import SyntheticsApi
import re

use_local_state = False

# if sys.argv:
#   if sys.argv[1] == "local":
#     use_local_state = True
#   else:
#     use_local_state = False

configuration = Configuration()
with ApiClient(configuration) as api_client:
  api_instance = SyntheticsApi(api_client)
  response = api_instance.list_tests()

alert_names = []

group_to_svc_map = {
  "<Group>": "<SERVICE>",
  "my-group": "My Service"
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
    # pagerduty_service_orig_name = alert_data['pagerduty_service'].replace("@pagerduty-{}_".format(env), "").lower().replace("_", "-")

    if pagerduty_service not in pagerduty_groups:
      pagerduty_groups[pagerduty_service] = [alert_data['formatted_name']]
    else:
      pagerduty_groups[pagerduty_service].append(alert_data['formatted_name'])

  return pagerduty_groups


def gen_tf_modules(alerts, pagerduty_groups, env):
  for pagerduty_svc_name, alert_names in pagerduty_groups.items():
    nr_sec_creds_key_name = "MY-HEADER" + pagerduty_svc_name.replace("-","").upper()
    nr_sec_creds_decr_name = "Client_name " + pagerduty_svc_name.replace("-"," ").replace("_","")

    new_pagerduty_svc_name = group_to_svc_map[pagerduty_svc_name]

    if individual_state:
      dir = "client_nam-" + env.lower() + "-" + pagerduty_svc_name + "-syn"
      if not os.path.exists(dir): 
        os.mkdir(dir)

      file_name = 'newrelic.tf'
      path = os.path.join(dir, file_name)
    else:
      path = "syn-" + pagerduty_svc_name + '.tf'

    file = open(path, "w")

    if individual_state:
      file.write(f'module "newrelic" {{\n')
    else:
      file.write(f'module "my_module_{pagerduty_svc_name.replace("-","_")}" {{\n')

    file.write('  source = "../modules/new-relic"\n')

    if pagerduty_svc_name == "aws":
      file.write(f'  name   = "client-{env.lower()}-{pagerduty_svc_name + "-syn"}"\n')
    else:
      file.write(f'  name   = "client-{env.lower()}-{pagerduty_svc_name}"\n')

    file.write(f'  pagerduty_services = ["{new_pagerduty_svc_name}"]\n')

    # Enable after migrating to PagerDuty
    # if pagerduty_svc_name in pagerduty_service_keys:
    #   file.write(f'  service_key = "{pagerduty_service_keys[pagerduty_svc_name]}"\n')
    # else:
    #   raise Exception("PagerDuty key not found for this service")

    # file.write('\n')
    # file.write('  custom_alerting = {}\n')
    file.write('\n')
    file.write('  custom_synthetics_monitors_scripted_api = {\n')

    for alert_name in alert_names:
      if alerts[alert_name]["url"] != None:
        file.write(f'    {alert_name} = {{\n')
        file.write(f'      locations_public = [\n')
        file.write(f'        "US_WEST_1"\n')
        file.write(f'      ]\n')
        file.write('\n')
        file.write(f'      locations_private           = []\n')

        if individual_state:
          file.write(f'      script                      = "./synthetic-check-api-{alert_name}.js"\n')
        else:
          file.write(f'      script                      = ""\n')
        
        file.write(f'      description                 = ""\n')

        if individual_state:
          file.write(f'      script_raw                  = ""\n')
        else:
          if alerts[alert_name]['x_token'] == None:
            file.write(f'      script_raw                  = templatefile("./synthetic-check-api.js.tftpl", {{ url = "{alerts[alert_name]["url"]}", token_stanza = "" }})\n')
          else:
            if create_local:
              file.write(f'      script_raw                  = templatefile("./synthetic-check-api.js.tftpl", {{ url = "{alerts[alert_name]["url"]}", token_stanza = "\'x-token\': \'${{var.api_token}}\',"}})\n')
            else:
              file.write(f'      script_raw                  = templatefile("./synthetic-check-api.js.tftpl", {{ url = "{alerts[alert_name]["url"]}", token_stanza = "\'x-token\': \'$secure.X_TOKEN\',"}})\n')

        file.write(f'      critical_threshold          = 0.95\n')
        file.write(f'      critical_threshold_duration = {alerts[alert_name]["min_failure_duration"]}\n')
        file.write(f'      default_alert               = true\n')
        # file.write(f'      period                      = "{alerts[alert_name]["period"]}"\n')
        # Override PagerDuty value per request of Client
        file.write(f'      period                      = "EVERY_5_MINUTES"\n')
        file.write('    }\n')
        file.write('\n')
    file.write('  }\n')
    file.write('\n')

    file.write('  custom_synthetics_secure_credential = {\n')
    file.write('    TOKEN = {\n')
    file.write(f'              key = "{nr_sec_creds_key_name}"\n')
    file.write(f'      description = "{nr_sec_creds_decr_name}"\n')
    file.write('      value        = "thisisnotarealtoken1234567890poiuytrewq"\n')
    file.write('    }\n')
    file.write('  }\n')
    file.write('\n')

    file.write('}\n')
    file.close()

    if individual_state:
      # setup.tf
      setup_file_name = 'setup.tf'
      setup_path = os.path.join(dir, setup_file_name)
      file = open(setup_path, "w")

      file.write('terraform {\n')
      file.write('  required_version = ">= 1.0.0"\n')
      file.write('\n')
      file.write('  backend "s3" {\n')

      if use_local_state:
        file.write('    bucket  = "terraform-states-fog"\n')
      else:
        file.write('    bucket  = "terraform-states"\n')

      file.write(f'    key     = "terraform.tfstate"\n')
      file.write('    region  = "us-east-1"\n')

      if use_local_state:
        file.write('    profile = "My-AWS-Profile"\n')
      else:
        file.write('    profile = "terraform-it"\n')

      file.write('    encrypt  = "true"\n')
      file.write('  }\n')
      file.write('}\n')
      file.write('\n')
      file.write('variable "ci" {\n')
      file.write('  description = "For use with automation pipelines"\n')
      file.write('  default     = false\n')
      file.write('  type        = bool\n')
      file.write('}\n')
      file.close()

      # main.tf
      main_file_name = 'main.tf'
      main_path = os.path.join(dir, main_file_name)
      file = open(main_path, "w")
      file.write('locals {}\n')
      file.close()

      # synthetic-check-api.js
      for alert_name in alert_names:
        if alerts[alert_name]["url"] != None:

          js_file_name = f'synthetic-check-api-{alert_name}.js'
          js_path = os.path.join(dir, js_file_name)
          file = open(js_path, "w")
          file.write('var assert = require("assert");\n')
          file.write(f'var myApiKey = $secure.{nr_sec_creds_key_name};\n')
          file.write('\n')
          file.write('var options = {\n')
          file.write(f'    uri: "{alerts[alert_name]["url"]}",\n')
          file.write('    headers: {\n')

          if alerts[alert_name]['x_token'] != None:
            file.write('        "x-token": myApiKey,\n')

          file.write('        "Content-Type": "application/json"\n')
          file.write('    }\n')
          file.write('}\n')
          file.write('\n')
          file.write('$http.get(options,\n')
          file.write('    function (err, response, body) {\n')
          file.write('      assert.equal(response.statusCode, 200, "Expected a 200 OK response");\n')
          file.write('      console.log("Response:", body.json);\n')
          file.write('    }\n')
          file.write(');\n')
          file.close()

      # Just in case I missed something
      os.system("terraform fmt -recursive")


env_name = "PROD"
prod_alerts = get_alerts(response, env_name)
prod_pagerduty_groups = get_pagerduty_groups(prod_alerts, env_name)
# Create modules in individual directories
individual_state = True
create_local = True
gen_tf_modules(prod_alerts, prod_pagerduty_groups, env_name)
