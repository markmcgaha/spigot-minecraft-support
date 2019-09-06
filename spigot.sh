#!/bin/bash

export JAVA_HOME=/opt/minecraft-server/jre/
EXEC_ACCOUNT=mcraft
MAILTO=mcop

SPIGOTDIR=/opt/minecraft-server/spigot
SPIGOTJAR=/opt/minecraft-server/spigot.jar
BACKUPTO=/opt/minecraft-server/backup
BACKUPPRE=minecraft-
BACKUPNUM=5
LEVEL_NAME='world'
ARCHIVE_PHRASE='Delete!'
WORLD_ARCHIVE=/opt/minecraft-server/old_worlds
ARCHIVE_TIMEOUT=60
RESTART_TIMEOUT=15

JAVARAM=$(awk '/MemTotal/ { MEM=$2 * .66; if ( MEM < 339664 ) MEM=339664; printf("%dk", MEM); }' /proc/meminfo)

if [[ `id -nu` != "${EXEC_ACCOUNT}" ]]; then
    echo "spigot must be run as user ${EXEC_ACCOUNT}"
    exit 1
fi

umask 002
cd "${SPIGOTDIR}"

while true; do
    printf "\rStarting Spigot Minecraft Server . . .\n"
    printf "RAM Allocation: $JAVARAM\n"

    ${JAVA_HOME}/bin/java -Xms${JAVARAM} -Xmx${JAVARAM} -XX:+UseConcMarkSweepGC -XX:+AlwaysPreTouch -jar "${SPIGOTJAR}" nogui

    # Get a timestamp when the server stops
    DT=`date +%Y%m%d%H%M%S`

    mail -s 'Spigot Stop' "${MAILTO}" <"${SPIGOTDIR}/logs/latest.log"

    printf "\n"
    printf "*********************************************\n"
    printf "*                                           *\n"
    printf "*    Performing Backup of Minecraft Data    *\n"
    printf "*                                           *\n"
    printf "*********************************************\n"
    printf "\n"
    #
    # Delete the oldest backups
    #
    ls ${BACKUPTO}/${BACKUPPRE}??????????????.tgz 2>/dev/null \
    | sort -r |tail -n "+${BACKUPNUM}" |xargs rm -f

    #
    # Create the new backup
    #
    tar -c ${SPIGOTDIR} 2>/dev/null |gzip -c5 >"${BACKUPTO}/${BACKUPPRE}${DT}.tgz"

    printf "*********************************************\n"
    printf "*                                           *\n"
    printf "* To remove the current minecraft world and *\n"
    printf "* create a new world when the server        *\n"
    printf "* restarts, type the exact phrase:          *\n"
    printf "*                                           *\n"
    printf "* %-41s *\n" "${ARCHIVE_PHRASE}"
    printf "*                                           *\n"
    printf "* You must type the phrase exactly          *\n"
    printf "* including upper case and punctuation to   *\n"
    printf "* remove the current world.                 *\n"
    printf "*                                           *\n"
    printf "*********************************************\n"
    unset USER_ARCHIVE_PHRASE
    while true; do
        printf "Enter the delete phrase or\n"
        read -t ${ARCHIVE_TIMEOUT} -p "press enter to continue: " USER_ARCHIVE_PHRASE

        if [[ $? == 0 ]]; then
            if [[ "${USER_ARCHIVE_PHRASE}" = "${ARCHIVE_PHRASE}" ]]; then
                printf "Archiving and removing the Minecraft world . . .\n"
                mkdir "${WORLD_ARCHIVE}/${DT}"
                mv "${SPIGOTDIR}/${LEVEL_NAME}" "${WORLD_ARCHIVE}/${DT}/"
                mv "${SPIGOTDIR}/${LEVEL_NAME}_nether" "${WORLD_ARCHIVE}/${DT}/"
                mv "${SPIGOTDIR}/${LEVEL_NAME}_the_end" "${WORLD_ARCHIVE}/${DT}/"
                break
            elif [[ "${USER_ARCHIVE_PHRASE}" = "" ]]; then
                break
            else
                printf "\n"
                continue
            fi
        else
            break
        fi
    done

    printf "\n"
    printf "*********************************************\n"
    printf "*                                           *\n"
    printf "* Restarting Minecraft server in %2d seconds *\n" ${RESTART_TIMEOUT}
    printf "*                                           *\n"
    printf "*********************************************\n"
    printf "\n"
    printf "Press CTRL-C to end Minecraft server or press enter to restart\n"
    T=${RESTART_TIMEOUT}
    while [[ $T -gt 0 ]]; do
        printf "* Restarting in ${T}  \r"
        read -t 1
        if [[ $? == 0 ]]; then
            break;
        fi;
        ((T--))
    done
done
