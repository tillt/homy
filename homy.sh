#!/bin/bash

AIRPORT=/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport

#
# Configure your SSID's here!
#
HOME_SSID="Boulderdash5"
WORK_SSID="D2iQ"

TEMPLATES=/Users/till/etc

last_location=""

function location() {
    local location=""
    local wifi=$($AIRPORT -I | awk '{if($1 == "SSID:"){print $2}}')

    case "$wifi" in
        $HOME_SSID)
            location=home
        ;;
        $WORK_SSID)
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
    local auto_resources="$TEMPLATES/auto_resources.$location"

    if [ -f "$auto_resources" -a "$location" != "$last_location" ]; then
        echo "Copying $auto_resources to /etc/auto_resources"
        automount -u
        cp "$auto_resources" /etc/auto_resources
        automount -vc
    fi

    last_location=$location
}

function main() {
    while :
    do
        process
        sleep 10
    done
}

main
