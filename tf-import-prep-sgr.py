import boto3
import sys

security_group_id = sys.argv[1]
tf_import_arguments_ingress = []
tf_import_arguments_egress = []

filter = {
  'Name': 'group-id',
  'Values': [
    security_group_id
  ]
}

ingress_with_cidr_blocks = []
egress_with_cidr_blocks = []

ec2_client = boto3.client("ec2", region_name = "us-east-1")
response = ec2_client.describe_security_group_rules(Filters=[filter])

def print_tf_blocks(sgr_type, tf_blocks):
  print(f'{sgr_type}_with_cidr_blocks = [')
  for block in tf_blocks:  
    print('  {')
    print('    description = "' + block["description"] + '"')
    print('    from_port = ' + block["from_port"])
    print('    to_port = ' + block["to_port"])
    print('    protocol = "' + block["protocol"] + '"')
    print('    cidr_blocks = "' + block["cidr"] + '"')
    print('  },')

  print(']\n')


for rule in response["SecurityGroupRules"]:
  if "Description" in rule:
    description = rule["Description"]
  else:
    description = ""

  if "FromPort" in rule:
    from_port = rule["FromPort"]
  
  if "ToPort" in rule:
    to_port = rule["ToPort"]
  
  if "IpProtocol" in rule:
    protocol = rule["IpProtocol"]
  
  if "CidrIpv4" in rule:
    cidr = rule["CidrIpv4"]

  if "IsEgress" in rule:
    is_egress = rule["IsEgress"]
    
    if is_egress:
      sgr_type = 'egress'
    else:
      sgr_type = 'ingress'

  tf_block = {
    'description': description,
    'from_port': str(from_port),
    'to_port': str(to_port),
    'protocol': protocol,
    'cidr': cidr
  }

  if sgr_type == 'ingress':
    ingress_with_cidr_blocks.append(tf_block)
    tf_import_arguments_ingress.append(f'{security_group_id}_{sgr_type}_{protocol}_{from_port}_{to_port}_{cidr}')

  if sgr_type == 'egress':
    egress_with_cidr_blocks.append(tf_block)
    tf_import_arguments_egress.append(f'{security_group_id}_{sgr_type}_{protocol}_{from_port}_{to_port}_{cidr}')

print_tf_blocks('ingress', ingress_with_cidr_blocks)
print_tf_blocks('egress', egress_with_cidr_blocks)

count = 0
for arg in tf_import_arguments_ingress:
  print(f'terraform import module.baseline_sg.aws_security_group_rule.ingress_with_cidr_blocks[{count}] {arg}')
  count += 1

count = 0
for arg in tf_import_arguments_egress:
  print(f'terraform import module.baseline_sg.aws_security_group_rule.egress_with_cidr_blocks[{count}] {arg}')
  count += 1
