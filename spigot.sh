#!/bin/bash
umask 002
shopt -s nocasematch
pushd () { command pushd "$@" > /dev/null; }
popd () { command popd "$@" > /dev/null; }

export JAVA_HOME=/opt/minecraft-server/jre/
EXEC_ACCOUNT=mcraft
MAILTO=mcop

SPIGOTDIR=/opt/minecraft-server/spigot
SPIGOTJAR=/opt/minecraft-server/spigot.jar
BACKUPTO=/opt/minecraft-server/backup
BACKUPPRE=minecraft-
BACKUPNUM=5
BANNER=/opt/minecraft-server/banner.txt
LEVEL_NAME='world'
WORLD_ARCHIVE=/opt/minecraft-server/worlds
START_TIMEOUT=60

JAVARAM=$(awk '/MemTotal/ { MEM=$2 * .66; if ( MEM < 339664 ) MEM=339664; printf("%dk", MEM); }' /proc/meminfo)

if [[ `id -nu` != "${EXEC_ACCOUNT}" ]]; then
    printf "** FAIL ** spigot must be run as user: %s\n" "${EXEC_ACCOUNT}"
    exit 1
fi

printf "\n"
printf "renice -n -18 -p $$\n"
printf "ionice -c 1 -n 0 -p $$\n"
printf "\n"

fnPrintBanner() {
    [[ -f "${BANNER}" ]] && cat "${BANNER}"
}

fnPrintMenu() {
    printf "\n\n"
    printf "The current world is:\n"
    printf "    %s\n\n" "$(fnGetCurrentWorld)"
    printf "[Enter] Sart the server\n"
    printf "[?] Print this menu\n"
    printf "[L] List worlds\n"
    printf "[W] Select a world\n"
    printf "[N] Create a new world\n"
    printf "[R] Rename a world\n"
    printf "[X] Exit the Minecraft Server\n"
}

fnGetCurrentWorld() {
    local d1=$(readlink -f "${SPIGOTDIR}/${LEVEL_NAME}")
    local d2=$(dirname "${d1}")
    basename "${d2}"
}

fnStartMinecraftServer() {
    pushd "${SPIGOTDIR}"
    printf "\rStarting Spigot Minecraft Server . . .\n"
    printf "RAM Allocation: $JAVARAM\n"
    ${JAVA_HOME}/bin/java -Xms${JAVARAM} -Xmx${JAVARAM} -XX:+UseConcMarkSweepGC -XX:+AlwaysPreTouch -jar "${SPIGOTJAR}" nogui
    mail -s 'Spigot Stop' "${MAILTO}" <"${SPIGOTDIR}/logs/latest.log"
    popd
}

fnBackup() {
    local DT=`date +%Y%m%d%H%M%S`

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
    # Backup the server
    #
    tar -ch ${SPIGOTDIR} 2>/dev/null |gzip -c5 >"${BACKUPTO}/${BACKUPPRE}${DT}.tgz"
}

fnListWorlds() {
    pushd "${WORLD_ARCHIVE}"
    printf "Minecraft Worlds\n"
    printf -- "----------------\n"
    du -sh *
    popd
}

fnGetWorldPath() {
    readlink -m "${WORLD_ARCHIVE}/${1}"
}

fnWorldPathIsValid() {
    local worldarchive=$(readlink -f "${WORLD_ARCHIVE}")
    [[ "${1}" ==  ${worldarchive}/* ]]
}

fnWorldExists() {
    local worldpath=$(fnGetWorldPath "${1}")
    fnWorldPathIsValid "${worldpath}" && [[ -d "${worldpath}" ]]
}

fnNewWorld() {
    local worldarchive=$(readlink -f "${WORLD_ARCHIVE}")
    local worldname
    local worldpath
    printf "\n\nWhat would you like to name the new world?\n"
    read -p "Enter World Name > " worldname
    worldpath=$(fnGetWorldPath "${worldname}")
    if ! fnWorldPathIsValid "${worldpath}"; then
        printf "\n** FAIL **: Invalid World Name\n\n"
        return
    fi

    if $(mkdir "${worldpath}"); then
        mkdir "${worldpath}/${LEVEL_NAME}"
        mkdir "${worldpath}/${LEVEL_NAME}_nether"
        mkdir "${worldpath}/${LEVEL_NAME}_the_end"

        printf "\nCreated world: %s\n\n" "${worldname}"
    else
        printf "\n** FAIL **: Could not create world\n\n"
    fi
}

fnRenameWorld() {
    local worldname
    local worldpath
    local worldnamenew
    local worldpathnew
    local updateworld=0

    printf "\n"
    while true; do
        printf "\nWhich world would you like to rename?\n"
        printf "Press [Enter] to see a list of worlds.\n"
        read -p "Enter World Name > " worldname

        [[ "${worldname}" != "" ]] && break
        printf "\n"
        fnListWorlds
    done;

    if ! fnWorldExists "${worldname}"; then
        printf "\n\n** FAIL **: world not found\n"
        return
    fi

    printf "What would you like the new name to be?\n"
    read -p "Enter New Name > " worldnamenew

    if fnWorldExists "${worldnamenew}"; then
        printf "** FAIL **: world already exists\n"
        return
    fi

    if [[ "$(fnGetCurrentWorld)" == "${worldname}" ]]; then
        updateworld=1
    fi

    worldpath=$(fnGetWorldPath "${worldname}")
    worldpathnew=$(fnGetWorldPath "${worldnamenew}")

    if fnWorldPathIsValid "${worldpathnew}"; then
        mv "${worldpath}" "${worldpathnew}"

        if [[ "${updateworld}" == "1" ]]; then
            fnLinkLevelByName "${worldnamenew}"
        fi

        printf "\nRenamed world: %s\n" "${worldname}"
        printf "           To: %s\n\n" "${worldnamenew}"
    else
        printf "** FAIL **: invalid world name\n"
    fi
}

fnSelectWorld() {
    local worldname

    printf "\n"
    while true; do
        printf "\nWhich world would you like to select?\n"
        printf "Press [Enter] to see a list of worlds.\n"
        read -p "Enter World Name > " worldname

        [[ "${worldname}" != "" ]] && break
        printf "\n"
        fnListWorlds
    done;

    fnLinkLevelByName "${worldname}"
    printf "\nThe current world is %s\n\n" "$(fnGetCurrentWorld)"
}

fnLinkLevelByName() {
    local worldpath=$(fnGetWorldPath "${1}")

    if ! fnWorldExists "${1}"; then
        printf "\n** FAIL **: World %s not found\n" "${1}"
        return
    fi

    if ! [[ -h "${SPIGOTDIR}/${LEVEL_NAME}" ]] \
    || ! [[ -h "${SPIGOTDIR}/${LEVEL_NAME}_nether" ]] \
    || ! [[ -h "${SPIGOTDIR}/${LEVEL_NAME}_the_end" ]]; then
        if [[ -e "${SPIGOTDIR}/${LEVEL_NAME}" ]] \
        || [[ -e "${SPIGOTDIR}/${LEVEL_NAME}_nether" ]] \
        || [[ -e "${SPIGOTDIR}/${LEVEL_NAME}_the_end" ]]; then
            printf "\n** FAIL **: World not in archive.\n"
            printf "Archive the current world before selecting a new world.\n"
            return
        fi
    fi

    rm -f "${SPIGOTDIR}/${LEVEL_NAME}"
    rm -f "${SPIGOTDIR}/${LEVEL_NAME}_nether"
    rm -f "${SPIGOTDIR}/${LEVEL_NAME}_the_end"

    ln -s "${worldpath}/${LEVEL_NAME}/" "${SPIGOTDIR}/${LEVEL_NAME}"
    ln -s "${worldpath}/${LEVEL_NAME}_nether/" "${SPIGOTDIR}/${LEVEL_NAME}_nether"
    ln -s "${worldpath}/${LEVEL_NAME}_the_end/" "${SPIGOTDIR}/${LEVEL_NAME}_the_end"
}

fnPrintBanner
fnPrintMenu
while true; do
    unset MENU_CMD
    read -N 1 -t ${START_TIMEOUT} -p "OPTION > " MENU_CMD
    [[ $? != 0 ]] && MENU_CMD=START
    case "${MENU_CMD}" in
        l)
            printf "\n\n"
            fnListWorlds
            printf "\n"
            continue;
            ;;
        w)
            fnSelectWorld
            continue
            ;;
        n)
            fnNewWorld
            continue
            ;;
        r)
            fnRenameWorld
            continue
            ;;
        x | q)
            printf "\n\nExiting the Minecraft server!\n\n"
            exit 0
            ;;
        '?')
            fnPrintMenu
            continue
            ;;
        START | $'\n')
            fnStartMinecraftServer
            fnBackup
            fnPrintBanner
            fnPrintMenu
            continue
            ;;
        *)
            printf "\r"
            continue
            ;;
    esac
done
