#!/bin/bash
ANSWER=`ps -C java -o vsize --sort vsize | tail -1`

if [ -z "$ANSWER" ]; then
    echo "0"
else
    echo $ANSWER
fi
