#!/bin/bash
SSH_KEYNAME_AZURE=${SSH_KEYNAME_AZURE:=REPLACE_ME_PRIVATE_KEY_AZURE}
ssh_private_keypath_aws=${SSH_PRIVATE_KEYPATH_AWS:=REPLACE_ME_PRIVATE_KEY_AWS.pem}

if [ ! -f ~/.ssh/config ] ; then
    echo """
Host aws-director
     # IdentityFile ~/.ssh/${ssh_private_keypath_aws}
     # User REPLACE_ME_SSH_USER
     Hostname 2.2.2.2
     StrictHostKeyChecking no
     ForwardAgent yes
     DynamicForward 8157

Host gcp-director
     # IdentityFile ~/.ssh/${SSH_PRIVATE_KEYPATH_GCP}
     # User REPLACE_ME_SSH_USER
     Hostname 8.8.8.8
     StrictHostKeyChecking no
     ForwardAgent yes
     DynamicForward 8158

Host azure-director
     # IdentityFile ~/.ssh/${SSH_KEYNAME_AZURE}
     # User REPLACE_ME_SSH_USER
     Hostname 1.1.1.1
     StrictHostKeyChecking no
     ForwardAgent yes
     DynamicForward 8159
""" > ~/.ssh/config
    chmod 644 ~/.ssh/config
    echo 'Wrote new skeleton ~/.ssh/config'
fi

exit 0
