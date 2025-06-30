#!/bin/bash

user=""

while [ "$1" != "" ]; do
    case $1 in
        -u | --user )
            shift
            user=$1
            ;;
        * )
            # unknown option
            ;;
    esac
    shift
done

if [ -n "$user" ]; then
    echo "hello world, $user!"
else
    echo "hello world!"
fi
