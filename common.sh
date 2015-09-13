#!/bin/bash

onMac() {
  if [ "$(uname)" == "Darwin" ]; then
    return 0;
  else
    return 1;
  fi
}

filesize() {
  if onMac; then
    stat -f%z $0
  else
    stat --printf="%s" $0
  fi
}
