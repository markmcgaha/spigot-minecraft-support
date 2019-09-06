#!/bin/bash

if [ -d "/opt/minecraft-server/jre/" ]; then
    export JAVA_HOME=/opt/minecraft-server/jre/
elif [ -d "~/jre/" ]; then
    export JAVA_HOME=~/jre/
fi


if [ -z "$1" ]; then
    echo 'ERROR: Revision is required'
    exit 1
fi

if [ -z "$JAVA_HOME" ]; then
    echo 'ERROR: JAVA_HOME not set'
    exit 1
fi

#git config --global --unset core.autocrlf

REV="$1"
if [ -d "$REV" ]; then
    rm -rf "$REV"
fi
mkdir "$REV"
cd "$REV"

wget https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
#${JAVA_HOME}/bin/java -Xms1024m -Xmx3584m -jar BuildTools.jar --rev latest
${JAVA_HOME}/bin/java -Xms1024m -Xmx3584m -jar BuildTools.jar --rev "$REV"
