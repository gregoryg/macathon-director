#!/bin/bash
if [ ! -f ~/.ssh/config ] ; then
    echo """
Host azure-director
     # IdentityFile ~/.ssh/<<REPLACE_ME_PRIVATE_KEY>>
     # User <<REPLACE_ME_SSH_USER>>
     Hostname 1.1.1.1
     StrictHostKeyChecking no
     ForwardAgent yes
     DynamicForward 8159

Host aws-director
     # IdentityFile ~/.ssh/<<REPLACE_ME_PRIVATE_KEY>>.pem
     # User <<REPLACE_ME_SSH_USER>>
     Hostname 1.1.1.1
     StrictHostKeyChecking no
     ForwardAgent yes
     DynamicForward 8157

""" > ~/.ssh/config
    chmod 644 ~/.ssh/config
    echo 'Wrote new skeleton ~/.ssh/config'
fi

exit 0
