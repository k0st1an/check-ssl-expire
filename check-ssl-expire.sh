#!/bin/bash

# Author: Konstantin Kruglov
# email: kruglovk@gmail.com
# license: MIT
# home: https://github.com/k0st1an/check-ssl-expire

HOST=
TIMEOUT=5
INTERVAL="days"
DATECMD="date"
TIMEOUTCMD="timeout"
USE_CURL="no"
THRESHOLD=
MSG="no"
FILE=

usage() {
  echo "Usage: `basename $0` -c example.com  [-yCmdHMstTX]"
  echo
  echo "  -c <str>  connect to host"
  echo "  -f <str>  path to certificate file"
  echo "  -C        using cURL"
  echo "  -y        how much is left in years"
  echo "  -m        how much is left in months"
  echo "  -d        how much is left in days (default)"
  echo "  -H        how much is left in hours"
  echo "  -M        how much is left in minutes"
  echo "  -s        how much is left in seconds"
  echo "  -t <int>  timeout (default: $TIMEOUT)"
  echo "  -T <int>  to print result if the value is a great then threshold"
  echo "  -X        human-readable result"
  echo "  -h        print this message"
  echo
  echo "Constants:"
  echo "  seconds in a year: 31536000"
  echo "  seconds in a month: 2592000"
  echo
  echo "Example: `basename $0` -c example.com -M"
  echo "12901"
  echo "Example: `basename $0` -c https://example.com -CM"
  echo "12901"
}

while getopts c:CymdHMsf:t:T:Xh option; do
  case "$option" in
    c ) HOST=$OPTARG;;
    C ) USE_CURL="yes";;
    y ) INTERVAL="years";;
    m ) INTERVAL="months";;
    d ) INTERVAL="days";;
    H ) INTERVAL="hours";;
    M ) INTERVAL="minutes";;
    s ) INTERVAL="seconds";;
    f ) FILE=$OPTARG;;
    t ) TIMEOUT=$OPTARG;;
    T ) THRESHOLD=$OPTARG;;
    X ) MSG="yes";;
    h ) usage; exit;;
  esac
done

if [[ -z $HOST && -z $FILE ]]; then
  echo "host or file not defined"
  exit 1
fi

if [[ $(uname) = "Darwin" ]]; then
  DATECMD="gdate"
  TIMEOUTCMD="gtimeout"

  if [[ ! -e $(which $DATECMD) ]]; then
    echo $DATECMD not found
    exit 1
  fi

  if [[ ! -e $(which $TIMEOUTCMD) ]]; then
    echo $TIMEOUTCMD not found
    exit 1
  fi
fi

if [[ ! -z $FILE ]]; then
  expiredTS=$($DATECMD -d "$(openssl x509 -noout -dates -in $FILE | grep notAfter | awk -F "=" '{print $2}')" "+%s")
else
  if [[ $USE_CURL = "yes" ]]; then
    expiredTS=$($DATECMD -d "$(curl -sv $HOST 2>&1 | grep "expire date:" | awk -F "e:" '{print $2}')" "+%s")
  else
    expiredTS=$($DATECMD -d "$($TIMEOUTCMD $TIMEOUT openssl s_client -connect $HOST:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | awk -F "=" '{print $2}')" "+%s")
  fi
fi

expiredSeconds=$(( $expiredTS - $($DATECMD +%s) ))

printResult() {
  if [[ ! -z $THRESHOLD ]] && [[ $THRESHOLD -lt $1 ]]; then
    return
  fi

  result=$1

  if [[ $MSG = "yes" ]]; then
    # -42
    if true | echo $1 | grep ^- > /dev/null ; then
      result="On host $HOST certificate expires in 0 $INTERVAL"
    else
      result="On host $HOST certificate expires in $1 $INTERVAL"
    fi
  fi

  echo $result
}

case $INTERVAL in
  "years" ) printResult $(( $expiredSeconds / 31536000 ));;
  "months" ) printResult $(( $expiredSeconds / 2592000 ));;
  "days" ) printResult $(( $expiredSeconds / 86400 ));;
  "hours" ) printResult $(( $expiredSeconds / 3600 ));;
  "minutes" ) printResult $(( $expiredSeconds / 60 ));;
  "seconds" ) printResult $expiredSeconds;;
esac
