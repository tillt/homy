#!/bin/bash

# homy - location aware configuration management

# homy -c PATH | [-h]

# We use Apple's own WiFi status tool - not sure if that is supported
# officially.
AIRPORT=/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport

templates=/usr/local/share/homy
config=/usr/local/etc/homy.json
state=/usr/local/var/run/homy/state
delay=10
home_ssid=""
work_ssid=""

jq_path="/usr/local/bin/jq"

last_location=""

configs=()
setups=()
teardowns=()

function usage() {
    echo "usage: $0 -o SSID -w SSID [-t PATH] [-d DURATION] | [-h]"
}

function dumpy() {
    echo "$(date +%FT%T): $1"
}

# Runs `airport -I` to get the currently connected WiFi SSID and uses that
# information to determine a location.
function location() {
    local location=""
    local wifi=$($AIRPORT -I | awk '{if($1 == "SSID:"){print $2}}')

    case "$wifi" in
        $home_ssid)
            location=home
        ;;
        $work_ssid)
            location=work
        ;;
        *)
            location=unknown
        ;;
    esac

    echo "$location"
}

function updateLocationState() {
    # We default to store the location in "/usr/local/var/run/homy/state".
    echo -n $1 > $state

    # Tell the status item app about the new state.
    osascript <<EOF
use framework "Foundation"
use framework "AppKit"

set aNC to current application's NSDistributedNotificationCenter's defaultCenter()

aNC's postNotificationName:"TTHomyStatusUpdate" object:(missing value) userInfo:(missing value) deliverImmediately:yes
EOF
}

function process() {
    local location=$(location)

    if [ "$location" != "$last_location" ]; then
        dumpy "--- $location --------------------------------------------------"

        updateLocationState $location

        typeset -i i=0 max=${#configs[*]}

        while (( i < max ))
        do
            destination_path="${configs[$i]}"
            destination_name=$(basename $destination_path)

            source_path=$templates/$destination_name.$location

            if [ -f "$source_path" ]; then
                dumpy "---- $destination_name ----"

                teardown="${teardowns[$i]}"
                if [[ ! -z $teardown ]]; then
                    dumpy "Making previously reachable resources unavailable: $teardown"
                    $($teardown)
                fi

                dumpy "Updating configuration $destination_path"
                cp "$source_path" "$destination_path"

                setup="${setups[$i]}"
                if [[ ! -z $setup ]]; then
                    dumpy "Making location specific resources available: $setup"
                    $($setup)
                fi
            fi

            i=i+1
        done

        dumpy "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - "

        dumpy "Awaiting next location change..."

    fi
    last_location=$location
}

function init() {
    IFS=$'\n' read -r -d '' -a configs \
        < <(set -o pipefail; cat $config | \
            $jq_path -r '.configurations[].path' && printf '\0')

    IFS=$'\n' read -r -d '' -a setups \
        < <(set -o pipefail; cat $config | \
            $jq_path -r '.configurations[].setup' && printf '\0')

    IFS=$'\n' read -r -d '' -a teardowns \
        < <(set -o pipefail; cat $config | \
            $jq_path -r '.configurations[].teardown' && printf '\0')

    home_ssid=$(cat $config | $jq_path -r '.home_ssid')
    work_ssid=$(cat $config | $jq_path -r '.work_ssid')
    delay=$(cat $config | $jq_path -r '.delay')
    templates=$(cat $config | $jq_path -r '.templates')
    state=$(cat $config | $jq_path -r '.state')

    if [ -z $home_ssid ] || [ -z $work_ssid ]; then
        usage
        exit
    fi
}

function main() {
    dumpy "= homy starting ===================================================="

    dumpy "== initialize configuration ========================================"

    init

    dumpy "Home SSID: ${home_ssid}"
    dumpy "Work SSID: ${work_ssid}"
    dumpy "Templates path: ${templates}"
    dumpy "Delay: ${delay}"
    dumpy "Configuration paths: [${configs[*]}]"

    dumpy "== daemon loop ====================================================="

    while :
    do
        process
        sleep $delay
    done
}

while [ "$1" != "" ]; do
    case $1 in
        -c | --config )         shift
                                config=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

main
