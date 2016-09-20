#!/usr/bin/env sh

if ! service libki status | grep '^libki_db.*Up'  > /dev/null; then RESTART=true; fi
if ! service libki status | grep '^libki_web.*Up' > /dev/null; then RESTART=true; fi

if $RESTART; then service libki start; fi
