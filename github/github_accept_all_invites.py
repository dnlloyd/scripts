#!/usr/bin/env python3

from requests.auth import HTTPBasicAuth
import requests

pat = 'xxxxxxxxxx'
url = 'https://api.github.com/user/repository_invitations'

header = {'Authorization': 'token %s' % pat}

repository_invites = requests.get('https://api.github.com/user/repository_invitations', headers=header)

#print('response: ' + str(repository_invites.json()))

for repository_invite in repository_invites.json():
  repository_id = repository_invite.get('id')
  print('accepting invite for https://api.github.com/user/repository_invitations/%s' % str(repository_id))
  accept_invite = requests.patch('https://api.github.com/user/repository_invitations/'+ str(repository_id),
    data={}, headers=header )