#!/bin/bash
DATA=$(cat /usr/local/var/run/homy/state)
LENGTH=$(echo $DATA | wc -c);
echo -e "HTTP/1.1 200 OK\nContent-Length: ${LENGTH}\n\n${DATA}";
