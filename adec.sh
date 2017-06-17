#!/usr/bin/env bash
# --------------------------------------------------------------
# adec
# a simple bash tool to decompile Android apps faster
#
# Copyright (c) 2017 - Giulio Mazzanti <mazzantibox@gmail.com>
#
# Based on initial idea by Marco Ronzano
#
# Projects wrapped:
# - dex2jar
# - jd-gui
#
# Java and adb must be installed in your $PATH.
#
#
# --------------------------------------------------------------
# CHANGELOG
#
# - v1.0 - 20170617
#   - added installer
#   - added list packages
#   - added package chooser
#   - added apk dump with adb
#   - added dex2jar
#   - added jd-gui
# --------------------------------------------------------------

RE_NUMBER="^[0-9]+$"
RE_APKNAME="s/^package\:\(.*\)\=//"
RE_APKPATH="s/^package\:\(.*\)\=.*/\1/"
RE_ESCAPESTR="s/\./\\\./g"

VERSION="1.0"
TOTEST=""

# draw line
function draw_line {
    echo "------------------------------------------------------------------------"
}

# show banner
function show_banner {
    draw_line
    echo " adec - v$VERSION - a simple bash tool to decompile Android apps faster"
    echo " copyright (c) 2017 - Giulio Mazzanti <mazzantibox@gmail.com>"
    draw_line
}

# do install
function do_install {
    mkdir -p common
    cd common

    echo "Installing dex2jar ..."
    curl -LOk https://bitbucket.org/pxb1988/dex2jar/downloads/dex2jar-2.0.zip
    rm -r dex2jar
    unzip -o dex2jar-2.0.zip
    mv dex2jar-2.0 dex2jar
    chmod +x dex2jar/*.sh
    rm dex2jar-2.0.zip

    echo "Installing jd-gui ..."
    curl -LOk https://github.com/java-decompiler/jd-gui/releases/download/v1.4.0/jd-gui-1.4.0.jar
    mkdir -p jd-gui
    mv jd-gui-1.4.0.jar jd-gui/jd-gui.jar

    #echo "Installing abe - Android Backup Extractor ..."
    #curl -LOk https://downloads.sourceforge.net/project/adbextractor/android-backup-extractor-20160710-bin.zip
    #rm -r abe
    #unzip -o android-backup-extractor-20160710-bin.zip
    #mv android-backup-extractor-20160710-bin abe
    #chmod +x abe/*.sh
    #rm android-backup-extractor-20160710-bin.zip

    cd ..
}

# do clean
function do_clean {

    echo "Removing all junk files..."
    if [ -d "user" ]; then
        rm -r user
    fi
    mkdir -p user

    echo "Done."
}

# return 1 if program is installed
function is_program_installed {
  local return_=1
  type $1 >/dev/null 2>&1 || { local return_=0; }
  echo "$return_"
}

# return 1 if npm package is installed
function is_npm_package_installed {
  local return_=1
  ls node_modules | grep $1 >/dev/null 2>&1 || { local return_=0; }
  echo "$return_"
}

# echo fail
function echo_fail {
  printf "\e[31m✘ ${1} missing"
  printf "\033[0m"
}

# echo pass
function echo_pass {
  printf "\e[32m✔ ${1}"
  printf "\033[0m"
}

# echo conditional
function echo_if {
  if [ $1 == 1 ]; then
    echo_pass $2
  else
    echo_fail $2
  fi
}

# check environment, platform and packages
function check_environment {
    OSNAME="$(uname -s)"
    OSPLATFORM=""
    if [ "$(uname)" == "Darwin" ]; then
        OSPLATFORM="osx"
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        OSPLATFORM="linux"
    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
        OSPLATFORM="mingw32"
    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
        OSPLATFORM="mingw64"
    fi

    echo "Checking packages installed on machine ..."
    IS_CURL="$(is_program_installed curl)"
    IS_JAVA="$(is_program_installed java)"
    IS_SED="$(is_program_installed sed)"
    IS_UNZIP="$(is_program_installed unzip)"
    IS_ADB="$(is_program_installed adb)"

    echo "curl     $(echo_if $IS_CURL)"
    echo "java     $(echo_if $IS_JAVA)"
    echo "sed      $(echo_if $IS_SED)"
    echo "unzip    $(echo_if $IS_UNZIP)"
    echo "adb      $(echo_if $IS_ADB)"

    if [ ! $IS_CURL == "1" ] ||
       [ ! $IS_JAVA == "1" ] ||
       [ ! $IS_SED == "1" ] ||
       [ ! $IS_UNZIP == "1" ] ||
       [ ! $IS_ADB == "1" ]; then
        echo "Please install missing packages!"
        exit
    fi
}

# check install
function check_install {
    if [ ! -d "common" ]; then
        read -p "Proceed to install third-party software? [Y/n]" -n 1 -r
        echo # move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            check_environment
            do_install
        else
            exit
        fi
    fi
}

# main function
function main {
    show_banner
    check_install
    do_clean

    echo "Getting installed app list from device ..."
    LSTPACKAGES="$(adb shell pm list packages -f)"
    if [ -z "$LSTPACKAGES" ] ; then
        exit;
    fi

    # loading all output into a variable NOT works on OSX
    #readarray -t ARRLIST <<<"$LSTPACKAGES"

    # WORKS ON OSX
    while read -r line; do ARRLIST+=("$line"); done <<<"$LSTPACKAGES"


    read -p "List all installed packages on device? [Y/n]" -n 1 -r
    echo # move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
       for i in "${!ARRLIST[@]}"
       do
           # echo "$i=>${ARRLIST[i]}"
           echo "$i=>$(echo ${ARRLIST[i]} | sed $RE_APKNAME)"
       done
    fi

    # read package index or package name like com.android
    echo -n "Enter package name, all lowercase (ex: com.android.chrome) or package number in list and press [ENTER]: "
    read PACKAGENAME
    if [ -z "$PACKAGENAME" ] ; then
        echo "ERROR: no app found!"
        exit;
    fi
    if [[ $PACKAGENAME =~ $RE_NUMBER ]] ; then
       # if a number is specified ...
       echo "${ARRLIST[$PACKAGENAME]}"

       TOTEST="${ARRLIST[$PACKAGENAME]}"
    else
       # if a package name is specified
       echo $PACKAGENAME

       ESCAPED=$(echo $PACKAGENAME | sed $RE_ESCAPESTR)

       for i in "${!ARRLIST[@]}"
       do
          if [[ "${ARRLIST[i]}" =~ $ESCAPED ]] ; then
             TOTEST="${ARRLIST[i]}"
             break
          fi
       done
    fi

    # check if not empty
    if [ -z "$TOTEST" ] ; then
        echo "ERROR: no app found!"
        exit;
    fi

    # get apk name
    MYAPKNAME=$(echo $TOTEST | sed $RE_APKNAME)
    # get apk path
    MYAPKPATH=$(echo $TOTEST | sed $RE_APKPATH)

    echo "File path: $MYAPKPATH"
    echo "File name: $MYAPKNAME"

    draw_line
    echo "Extracting apk from device ..."
    adb pull $MYAPKPATH
    mv *.apk user/

    draw_line
    echo "Extracting jar via dex2jar ..."
    sh common/dex2jar/d2j-dex2jar.sh user/*.apk
    mv *.jar user/
    echo "Done."

    draw_line
    read -p "Launch jd-gui? [Y/n]" -n 1 -r
    echo # move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        java -jar common/jd-gui/jd-gui.jar ./user/*.jar &
        exit;
    fi
}

# run the main and start the stuff!
main
