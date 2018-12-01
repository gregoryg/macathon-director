#!/bin/bash -e
function setup_analytics () {
    # make good defaults for use of Beeline and Impala on this edge node
    echo "Setting up defaults for impala-shell and Beeline"
    impalad=$(curl --silent -u "${cm_username}:${cm_password}" "http://${cm_host_port}/api/v14/hosts?view=FULL" | jq -r '[.items[] | select(.roleRefs[].roleName | contains("-IMPALAD")) | .ipAddress] | first ')
    echo "[impala]
    impalad=${impalad}:21000
    " > ~/.impalarc
    hiveserver2=$(curl --silent -u ${cm_username}:${cm_password} http://${cm_host_port}/api/v14/hosts?view=full | jq -r '[.items[] | select(.roleRefs[].roleName | contains("HIVESERVER2")) .hostname] | first')
    # start up a beeline command and then save config to ~/.beeline/beeline.properties
    beeline -u "jdbc:hive2://${hiveserver2}:10000/default" -n ${USER} <<EOF
!save
!quit
EOF
    echo "To run beeline without parameters, use 'beeline -r'"
}

