#~/bin/bash

function setup_cowsay () {
    echo "Fixing up .bashrc"
    sudo yum -y install cowsay fortune-mod
    tee -a ~/.bashrc <<EOF
export PS1='\u@gateway: \w #$ '
# test if in interactive shell
if [[ \$- =~ "i" ]] ; then
    # echo "Streamsets URL: http://`hostname -f`:18630/"
    # echo "Jupyter notebook URL: http://`hostname -f`:8880"
    # echo "RStudio URL: http://`hostname -f`:8787"
    ~/bin/cowme
fi
EOF
    mkdir -p ~/bin
    tee ~/bin/cowme << EOF
#!/bin/bash
if type fortune cowsay >/dev/null
then
    IFS=',' read -r -a cowopts <<< "b,g,p,s,t,w,y"
    if [ \$((RANDOM % 4)) == 0 ] ; then
        cowcmd="cowsay"
    else
        cowcmd="cowthink"
    fi
    fortune -s | \${cowcmd} -\${cowopts[\$((RANDOM % \${#cowopts[@]}))]}
fi
EOF
    chmod 755 ~/bin/cowme
}

# test if in interactive shell
if [[ \$- =~ "i" ]] ; then
    setup_cowsay
    ~/bin/cowme
fi
