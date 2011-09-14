#!/bin/bash
#-------------------
#- FUNÇÕES MÁGICAS -
#-------------------
declare -i depth=0
declare logging=0
declare -A events

print() {
	local len=0
	let len=0$depth*3
	whitespace="$(printf '%*s' $len)$*"
	if [ $logging -eq 1 ]; then
		echo "$whitespace" | log_writer "$LOGS_DIR/$LOG"
	else
		echo "$whitespace"
	fi
}
debug() {
	print "$*"
}
trace() {
	print "$*"
}
error() {
	local ERR=$1
	shift
	print "[ERROR] $*"
	exit $ERR
}
call() {
	local FUNCTION_NAME=$1
	local PARM_TYPE="$(type -t $FUNCTION_NAME)"

	if [ "$PARM_TYPE" == "function" ] || [ "$PARM_TYPE" == "file" ]; then			
		shift
		debug "[INICIANDO $PARM_TYPE]   $FUNCTION_NAME($*)"
		let "depth += 1"
		if [ "$PARM_TYPE" == "function" ]; then
			$FUNCTION_NAME $*
		else
			$FUNCTION_NAME $* 2>&1 | log_writer "$LOGS_DIR/$LOG"
		fi
		let "depth -= 1"
		debug "[FINALIZANDO $PARM_TYPE] $FUNCTION_NAME"
	fi
}

add_on_event() {
	local eventName=$1
	local currentEvents=${events[$eventName]}
	local addEventBefore=$3
	if [ "$currentEvents" == "" ]; then
		events[$eventName]="$2"
	else	
		if [ "$addEventBefore" != "" ]; then
			echo "Eventos ja adicionados $currentEvents"
			echo "Evento a ser encontrado $3"
			local positionUntilFind=$(echo $currentEvents | awk '{ print index($0,"'"$addEventBefore"'") }')
			echo "posicao $positionUntilFind"
		#	local beforeEvents=$(expr substr $currentEvents 0 $(expr $positionUntilFind - 2))
		 	local beforeEvents=$(echo | awk '{ print substr("'"$currentEvents"'",0,"'"$(expr $positionUntilFind - 2)"'") }')
			echo "Before events $beforeEvents"
	#		currentEvents=
		fi
		events[$eventName]="$currentEvents;$2"
	fi
	trace "[ASSOCIANDO ao evento '$eventName'] '$2'"
}

call_event() {
	local eventName=$1
	echo "Event Name = $eventName"
	echo "Events: ${events[$eventName]}"
	local arr=$(echo ${events[$eventName]} | tr ";" "\n")
	trace "[INICIANDO evento '$eventName']"
	shift
	let "depth += 1"
	for x in $arr
	do
		call "$x" $*
	done
	let "depth -= 1"
	trace "[FINALIZANDO evento '$eventName']"	
}

get_var() {
	local VARNAME="$1"
	echo "$(eval echo '$'$VARNAME)"
}
set_var() {
	local VARNAME="$1"
	shift
	eval "$VARNAME='$*'"
}
define() {
	local VARNAME="$1"
	set_var $*
	local VALUE=$(get_var $VARNAME)
	trace "[VARIAVEL]    '$VARNAME'='$VALUE'"
}

define_path() {
	define $*
	shift
	require_path "$*"
}
require_path() {
	if [ ! -e "$1" ]; then
		error 1 "O caminho $1 definido na variavel $2 não é valido"
	fi
}
define_path_once() {
	local VARNAME="$1"
	local VALUE="$(get_var $VARNAME)"
	if [ "$VALUE" == "" ] ; then
		define_path $*
	else
		trace "[PATH] $VARNAME não foi substituida. '$VARNAME'='$VALUE'"
		require_path "$VALUE" "\$VALUE"
	fi
}

define_once() {
	local VARNAME="$1"
	local VALUE="$(get_var $VARNAME)"
	if [ "$VALUE" == "" ] ; then
		define $*
	else
		trace "[VARIAVEL] $VARNAME não foi substituida. '$VARNAME'='$VALUE'"
	fi
}

date_now(){
	echo "$(date +%Y.%m.%d.%H.%M.%S)"
}
base_copy() {
	trace "[COPIANDO] $*"
	cp $*
}
base_rm(){
	trace "[REMOVENDO] $*"
	rm -rf "$*"
}

#--------------------------------------
#- SECÃO DE FUNÇÕES BASICAS DO SCRIPT -
#--------------------------------------

global_variables() {
	call "before_global_variables"
	define SCRIPT_NAME "$0"
	define SCRIPT_PATH "$(cd $(dirname $SCRIPT_NAME) && pwd)"
	define AMBIENTE_PATH "$(cd $SCRIPT_PATH/.. && pwd)"
	define AMBIENTE "$(basename $AMBIENTE_PATH)"
	call "after_global_variables"
}

help_variables() {
	call "before_help_variables"
	define COMMANDS "start|pre_start|post_stop|start_only"	
	call "after_help_variables"
}

help() {
	print "Usage: $SCRIPT_NAME ($COMMANDS)"
}

main() {
	
	call_event "inicioScript"
	define ACTION $1
	shift
	call "setup"
	case $ACTION in
		start) 
			trap "post_stop $*" 0 SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM
			call "pre_start" $*
			call "start" $*
		;; 
		# pre_start utilizado pelo Upstart para chamar somente o evento de pre_start
		pre_start) 
			call "pre_start" $*
		;;
		# post_stop utilizado pelo Upstart para chamar somente o evento de post_stop
		post_stop) 
			call "post_stop" $*
		;;
		# start_only utilizado pelo Upstart para chamar somente o evento de post_stop
		start_only)
			call "start" $*
		;;
		*)
		if [ "$(type -t $ACTION)" == "function" ]; then
			call "$ACTION" $*
		else 
			help $ACTION $*
			exit 1;
		fi
		;;
	esac
}

#ADICIONAR EVENTOS NO INICIO FORA DE FUNCOES
setup() {	
	call_event "variables"
	call "check_mandatory_variables"
	call "pre_log"
	do_log
}

pre_start() {
	call_event "on_pre_start"
}

start() {
	call_event "on_start"
}

before_post_stop(){
	define DATA_STOP $(eval date_now)
}

post_stop() {
	do_log
	call_event "on_post_stop"
}


#VARIAVEL DEPOIS CAMINHO
check_mandatory_variables() {
	require_path "$APPS_DIR" "\$APPS_DIR"
	require_path "$APP_DIR" "\$APP_DIR"
}


#---------------------------------------
#- SECÃO DE FUNÇÕES PARA EXECUÇÃO LOG -
#---------------------------------------

do_log() {
	define logging 1
}
dont_log() {
	define logging 0
}
log_variables() {
	call "before_log_variables"
	define LOGS_DIR "$SCRIPT_PATH/../logs"
	define LOG "$APP.console.log"
	define DATA_START $(date_now)
	define LOG_ROTATE_CONF "$LOGS_DIR/$APP.rotate"
	define ATUAL_LOG_FOLDER "$APP""_$DATA_START"
	define LOG_FOLDER "$LOGS_DIR/$ATUAL_LOG_FOLDER"
	call "after_log_variables"
}

log_writer() {
	oldIFS="$IFS"
	IFS=¬
	let contador=0;
	while read LINE; do
		echo "$LINE"
		echo "$LINE" >> $1
		let contador=$(expr $contador + 1)
		if [ $contador -eq 10 ]; then	
			logrotate $LOG_ROTATE_CONF
			contador=0
		fi
	done
	IFS=$oldIFS
}

log_rotate_template_generator(){
	sed -e "s/LOG_FILE_NAME/$(echo $LOGS_DIR | sed -e 's/\//\\\//g')\/$LOG/" $SCRIPT_PATH/../../common/include/logrotate.template > $LOG_ROTATE_CONF
}

pre_log() {
	call "check_log_folder"
	call "log_rotate_template_generator"

	if [ -e $LOGS_DIR/$LOG ]; then
		find $LOGS_DIR -name "$LOG*" | while read log_file
		do
		 	base_rm "$log_file"
		done
	fi
}

check_log_folder() {
	if [ ! -d $LOGS_DIR ]; then
		cd $AMBIENTE_PATH && mkdir "logs"
	fi
}

log_tar(){
	mkdir $LOG_FOLDER
	find $LOGS_DIR -name "$LOG*" | while read log_file
	do
		base_copy "$log_file" $LOG_FOLDER
	done
	dont_log
	define TAR_FILE_NAME "$ATUAL_LOG_FOLDER.tar.gz"
	tar zcfP $LOGS_DIR/$TAR_FILE_NAME $LOGS_DIR/$ATUAL_LOG_FOLDER
	cd "$LOGS_DIR/" && rm -rf $ATUAL_LOG_FOLDER
}

add_on_event "inicioScript" "help_variables"
add_on_event "variables" "global_variables"
add_on_event "variables" "log_variables"
add_on_event "on_post_stop" "log_variables_on_stop"
add_on_event "on_post_stop" "log_tar"
