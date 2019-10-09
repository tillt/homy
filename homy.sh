#!/bin/bash

# homy - location aware configuration management

# homy -o SSID -w SSID [-t PATH] [-d DURATION] | [-h]
#  -o SSID      home WiFi SSID.
#  -w SSID      work WiFi SSID.
#  -t PATH      template location.
#  -d DURATION  poll delay.
#  -h

# We use Apple's own WiFi status tool - not sure if that is supported
# officially.
AIRPORT=/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport

templates=/usr/local/share/homy
delay=10
home_ssid=""
work_ssid=""

# Fpr every configuration we want to update, its location as well as a setup
# and a teardown command are supplied.
configs=("/etc/auto_resources")
setups=("automount -vc")
teardowns=("automount -u")

last_location=""

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

function process() {
    local location=$(location)

    if [ "$location" != "$last_location" ]; then
        dumpy "Detected location is $location"

        typeset -i i=0 max=${#configs[*]}

        while (( i < max ))
        do
            destination_path="${configs[$i]}"
            destination_name=$(basename $destination_path)

            source_path=$templates/$destination_name.$location

	    if [ -f "$source_path" ]; then
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

    fi
    last_location=$location
}

function main() {
    dumpy "= homy starting ===================================================="
    dumpy "Home SSID: ${home_ssid}"
    dumpy "Work SSID: ${work_ssid}"
    dumpy "Templates path: ${templates}"
    dumpy "Delay: ${delay}"
    dumpy "Configurations: ${configs[*]}"
    dumpy "--------------------------------------------------------------------"
    while :
    do
        process
        sleep $delay
    done
}

while [ "$1" != "" ]; do
    case $1 in
        -o | --home )           shift
                                home_ssid=$1
                                ;;
        -w | --work )           shift
                                work_ssid=$1
                                ;;
        -d | --delay )          shift
                                delay=$1
                                ;;
        -t | --templates )      shift
                                templates=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ -z $home_ssid ] || [ -z $work_ssid ]; then
    usage
    exit
fi

main
