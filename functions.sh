#!/bin/bash

function question() {
	zenity --question --text "$@" 2>/dev/null
}
function info() {
	zenity --info --text "$@" 2>/dev/null
}
function panic() {
	zenity --error --text "$@\n\n Log file : $LOG_FILE" 2>/dev/null
	exit 1
}
function password() {
	zenity --password --text "$@" 2>/dev/null
}

function input() {
	DEFAULT=""
	[ -n "$2" ] && DEFAULT=" --entry-text $2"
	zenity --entry --text "$1" $DEFAULT 2>/dev/null
}
