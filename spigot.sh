#!/bin/bash
umask 002
shopt -s nocasematch
pushd () { command pushd "$@" > /dev/null; }
popd () { command popd "$@" > /dev/null; }

export JAVA_HOME=/opt/minecraft-server/jre/
EXEC_ACCOUNT=mcraft
MAILTO=mcop

CONFIG=/opt/minecraft-server/environment/spigot
SERVERJAR=/opt/minecraft-server/spigot.jar
BACKUPTO=/opt/minecraft-server/backup
BACKUPPRE=minecraft-
BACKUPNUM=5
BANNER=/opt/minecraft-server/banner.txt
LEVEL_NAME='world'
WORLD_ARCHIVE=/opt/minecraft-server/environment/world
CONFIG_ARCHIVE=/opt/minecraft-server/environment/config
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

fnMenuMainPrint() {
    printf "\n\n"
    printf "The current config is:\n"
    printf "    %s\n\n" "$(fnGetCurrentConfig)"
    printf "The current world is:\n"
    printf "    %s\n\n" "$(fnGetCurrentWorld)"
    printf "\n"
    printf "MAIN MENU\n"
    printf -- "---------\n"
    printf "[Enter] Sart the server\n"
    printf "[?] Print this menu\n"
    printf "[W] World Menu\n"
    printf "[C] Config Menu\n"
    printf "[X] Exit the Minecraft Server\n"
}

fnMenuWorldPrint() {
    printf "\n\n"
    printf "The current world is:\n"
    printf "    %s\n\n" "$(fnGetCurrentWorld)"
    printf "\n"
    printf "WORLD MENU\n"
    printf -- "----------\n"
    printf "[?] Print this menu\n"
    printf "[L] List worlds\n"
    printf "[S] Select a world\n"
    printf "[C] Create a new world\n"
    printf "[R] Rename a world\n"
    printf "[X] Previous Menu\n"
}

fnMenuConfigPrint() {
    printf "\n\n"
    printf "The current config is:\n"
    printf "    %s\n\n" "$(fnGetCurrentConfig)"
    printf "\n"
    printf "CONFIG MENU\n"
    printf -- "-----------\n"
    printf "[?] Print this menu\n"
    printf "[L] List configs\n"
    printf "[S] Select an config\n"
    printf "[C] Create a new config\n"
    printf "[R] Rename an config\n"
    printf "[X] Previous Menu\n"
}


fnGetCurrentConfig() {
    local d1=$(readlink -f "${CONFIG}")
    basename "${d1}"
}


fnGetCurrentConfig() {
    local d1=$(readlink -f "${CONFIG}")
    basename "${d1}"
}

fnGetCurrentWorld() {
    local d1=$(readlink -f "${CONFIG}/${LEVEL_NAME}")
    local d2=$(dirname "${d1}")
    basename "${d2}"
}

fnStartMinecraftServer() {
    pushd "${CONFIG}"
    printf "\rStarting Spigot Minecraft Server . . .\n"
    printf "RAM Allocation: $JAVARAM\n"
    ${JAVA_HOME}/bin/java -Xms${JAVARAM} -Xmx${JAVARAM} -XX:+UseConcMarkSweepGC -XX:+AlwaysPreTouch -jar "${SERVERJAR}" nogui
    mail -s 'Spigot Stop' "${MAILTO}" <"${CONFIG}/logs/latest.log"
    sleep 4
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
    tar -ch ${CONFIG} 2>/dev/null |gzip -c5 >"${BACKUPTO}/${BACKUPPRE}${DT}.tgz"
}

fnListConfigs() {
    pushd "${CONFIG_ARCHIVE}"
    printf "Minecraft Configs\n"
    printf -- "-----------------\n"
    du -sh *
    popd
}

fnListWorlds() {
    pushd "${WORLD_ARCHIVE}"
    printf "Minecraft Worlds\n"
    printf -- "----------------\n"
    du -sh *
    popd
}

fnGetConfigPath() {
    readlink -m "${CONFIG_ARCHIVE}/${1}"
}

fnGetWorldPath() {
    readlink -m "${WORLD_ARCHIVE}/${1}"
}

fnConfigPathIsValid() {
    local configarchive=$(readlink -f "${CONFIG_ARCHIVE}")
    [[ "${1}" ==  ${configarchive}/* ]]
}

fnWorldPathIsValid() {
    local worldarchive=$(readlink -f "${WORLD_ARCHIVE}")
    [[ "${1}" ==  ${worldarchive}/* ]]
}

fnConfigExists() {
    local configpath=$(fnGetConfigPath "${1}")
    fnConfigPathIsValid "${configpath}" && [[ -d "${configpath}" ]]
}

fnWorldExists() {
    local worldpath=$(fnGetWorldPath "${1}")
    fnWorldPathIsValid "${worldpath}" && [[ -d "${worldpath}" ]]
}

fnNewConfig() {
    local configarchive=$(readlink -f "${CONFIG_ARCHIVE}")
    local configname
    local configpath
    printf "\n\nWhat would you like to name the new config?\n"
    read -p "Enter Config Name > " configname
    configpath=$(fnGetConfigPath "${configname}")

    if ! fnConfigPathIsValid "${configpath}"; then
        printf "\n** FAIL **: Invalid Config Name.\n\n"
        return
    fi

    if fnConfigExists "${configname}"; then
        printf "\n** FAIL **: Config already exists.\n\n"
        return
    fi

    if $(mkdir "${configpath}"); then
        printf "eula=true\n" >"${configpath}/eula.txt"
        printf "\nCreated config: %s\n\n" "${configname}"
    else
        printf "\n** FAIL **: Could not create config.\n\n"
    fi
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

fnRenameConfig() {
    local configname
    local configpath
    local confignamenew
    local configpathnew
    local updatepath=0

    printf "\n"
    while true; do
        printf "\nWhich config would you like to rename?\n"
        printf "Press [Enter] to see a list of configs.\n"
        read -p "Enter Config Name > " configname

        [[ "${configname}" != "" ]] && break
        printf "\n"
        fnListConfigs
    done;

    if ! fnConfigExists "${configname}"; then
        printf "\n\n** FAIL **: Config not found\n"
        return
    fi

    printf "What would you like the new name to be?\n"
    read -p "Enter New Name > " confignamenew

    if fnConfigExists "${confignamenew}"; then
        printf "** FAIL **: Config already exists\n"
        return
    fi

    if [[ "$(fnGetCurrentConfig)" == "${configname}" ]]; then
        updateconfig=1
    fi

    configpath=$(fnGetConfigPath "${configname}")
    configpathnew=$(fnGetConfigPath "${confignamenew}")

    if fnConfigPathIsValid "${configpathnew}"; then
        mv "${configpath}" "${configpathnew}"

        if [[ "${updateconfig}" == "1" ]]; then
            fnLinkLevelByName "${confignamenew}"
        fi

        printf "\nRenamed config: %s\n" "${configname}"
        printf "            To: %s\n\n" "${confignamenew}"
    else
        printf "** FAIL **: Invalid config name\n"
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

fnSelectConfig() {
    local cfgname

    printf "\n"
    while true; do
        printf "\nWhich config would you like to select?\n"
        printf "Press [Enter] to see a list of configs.\n"
        read -p "Enter Config Name > " cfgname

        [[ "${cfgname}" != "" ]] && break
        printf "\n"
        fnListConfigs
    done;

    fnLinkConfigByName "${cfgname}"
    printf "\nThe current config is %s\n\n" "$(fnGetCurrentConfig)"
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

fnLinkConfigByName() {
    local configpath=$(fnGetConfigPath "${1}")

    if ! fnConfigExists "${1}"; then
        printf "\n** FAIL **: Config %s not found\n" "${1}"
        return
    fi

    rm -f "${CONFIG}"
    ln -s "${configpath}/" "${CONFIG}"
}

fnLinkLevelByName() {
    local worldpath=$(fnGetWorldPath "${1}")

    if ! fnWorldExists "${1}"; then
        printf "\n** FAIL **: World %s not found\n" "${1}"
        return
    fi

    if ! [[ -h "${CONFIG}/${LEVEL_NAME}" ]] \
    || ! [[ -h "${CONFIG}/${LEVEL_NAME}_nether" ]] \
    || ! [[ -h "${CONFIG}/${LEVEL_NAME}_the_end" ]]; then
        if [[ -e "${CONFIG}/${LEVEL_NAME}" ]] \
        || [[ -e "${CONFIG}/${LEVEL_NAME}_nether" ]] \
        || [[ -e "${CONFIG}/${LEVEL_NAME}_the_end" ]]; then
            printf "\n** FAIL **: World not in archive.\n"
            printf "Archive the current world before selecting a new world.\n"
            return
        fi
    fi

    rm -f "${CONFIG}/${LEVEL_NAME}"
    rm -f "${CONFIG}/${LEVEL_NAME}_nether"
    rm -f "${CONFIG}/${LEVEL_NAME}_the_end"

    ln -s "${worldpath}/${LEVEL_NAME}/" "${CONFIG}/${LEVEL_NAME}"
    ln -s "${worldpath}/${LEVEL_NAME}_nether/" "${CONFIG}/${LEVEL_NAME}_nether"
    ln -s "${worldpath}/${LEVEL_NAME}_the_end/" "${CONFIG}/${LEVEL_NAME}_the_end"
}

fnMenuWorld() {
    fnMenuWorldPrint
    while true; do
        unset MENU_CMD
        read -N 1 -p "World Menu > " MENU_CMD
        case "${MENU_CMD}" in
            l)
                printf "\n\n"
                fnListWorlds
                printf "\n"
                continue;
                ;;
            s)
                fnSelectWorld
                continue
                ;;
            c)
                fnNewWorld
                continue
                ;;
            r)
                fnRenameWorld
                continue
                ;;
            x | q)
                break;
                ;;
            '?')
                fnMenuWorldPrint
                continue
                ;;
            *)
                printf "\r"
                printf ' %.0s' {1..80}
                printf "\r"
                continue
                ;;
        esac
    done
}

fnMenuConfig() {
    fnMenuConfigPrint
    while true; do
        unset MENU_CMD
        read -N 1 -p "Config Menu > " MENU_CMD
        case "${MENU_CMD}" in
            l)
                printf "\n\n"
                fnListConfigs
                printf "\n"
                continue;
                ;;
            s)
                fnSelectConfig
                continue
                ;;
            c)
                fnNewConfig
                continue
                ;;
            r)
                fnRenameConfig
                continue
                ;;
            x | q)
                break;
                ;;
            '?')
                fnMenuConfigPrint
                continue
                ;;
            *)
                printf "\r"
                printf ' %.0s' {1..80}
                printf "\r"
                continue
                ;;
        esac
    done
}

fnMenuMain() {
    fnMenuMainPrint
    while true; do
        unset MENU_CMD
        read -N 1 -t ${START_TIMEOUT} -p "Main Menu > " MENU_CMD
        [[ $? != 0 ]] && MENU_CMD=START
        case "${MENU_CMD}" in
            # World Maintenance
            w)
                fnMenuWorld
                fnMenuMainPrint
                continue;
                ;;
            c)
                fnMenuConfig
                fnMenuMainPrint
                continue
                ;;
            x | q)
                printf "\n\nExiting the Minecraft server!\n\n"
                exit 0
                ;;
            '?')
                fnMenuMainPrint
                continue
                ;;
            START | $'\n')
                fnStartMinecraftServer
                fnBackup
                fnPrintBanner
                fnMenuMainPrint
                continue
                ;;
            *)
                printf "\r"
                printf ' %.0s' {1..80}
                printf "\r"
                continue
                ;;
        esac
    done
}

fnPrintBanner
fnMenuMain
