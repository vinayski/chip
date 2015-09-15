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
    stat -f "%z" $1
  else
    stat --printf="%s" $1
  fi
}
