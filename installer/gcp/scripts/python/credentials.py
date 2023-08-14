"""
Before running:

export GOOGLE_APPLICATION_CREDENTIALS=$HOME/.gcp/osServiceAccount.json
"""

import argparse
import os
import googleapiclient.discovery
from google.oauth2 import service_account
from termcolor import colored


parser = argparse.ArgumentParser('Determine if credentials exist.')
parser.add_argument('-p', '--project', type=str, default='openshift-dev-installer', help='project to search for credentials')
parser.add_argument('--permissions', type=str, nargs='+', default=[], help='list of permissions to test')
args = parser.parse_args()


credentials = service_account.Credentials.from_service_account_file(
    filename=os.environ["GOOGLE_APPLICATION_CREDENTIALS"],
    scopes=["https://www.googleapis.com/auth/cloud-platform"],
)

service = googleapiclient.discovery.build("cloudresourcemanager", "v1", credentials=credentials)
permissions = {"permissions": args.permissions}

request = service.projects().testIamPermissions(
    resource=args.project, body=permissions
)
returnedPermissions = request.execute()

if not isinstance(returnedPermissions, dict) or 'permissions' not in returnedPermissions:
    print(colored("failed to access permissions", 'red'))
    exit(1)

if returnedPermissions['permissions']:
    print("Found Permissions:")
    for permission in returnedPermissions['permissions']:
        print(colored(permission, 'green'))
    
notFound = list(set(args.permissions) - set(returnedPermissions['permissions']))
if notFound:
    print("Missing Permissions:")
    for	permission in notFound:
        print(colored(permission, 'red'))

