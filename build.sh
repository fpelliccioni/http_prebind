#!/bin/sh
mkdir -p ebin/
erl -pa /usr/lib/ejabberd/ebin -pz ebin -make
