#!/bin/bash

#-------------------
#- FUNÇÕES MÁGICAS -
#-------------------
declare -i depth=0

print() {
	local len=0
	let len=0$depth*3
	echo "$(printf '%*s' $len)$*" 
	echo "$(printf '%*s' $len)$*" | log_writer "log.log"
}
debug() {
	print "$*" 2>&1
}
trace() {
	print "$*" 2>&1
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
	if [ "$PARM_TYPE" == "function"  ] || [ "$PARM_TYPE" == "file" ] ; then		
		shift
		debug "[INICIANDO $PARM_TYPE]   $FUNCTION_NAME($*)"
		let "depth += 1"
		$FUNCTION_NAME $*
		let "depth -= 1"
		debug "[FINALIZANDO $PARM_TYPE] $FUNCTION_NAME"
	fi
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
		error 1 "O PATH '$1' NAO EXISTE!"
	fi
}
define_path_once() {
	local VARNAME="$1"
	local VALUE="$(get_var $VARNAME)"
	if [ "$VALUE" == "" ] ; then
		define_path $*
	else
		trace "[PATH] $VARNAME não foi substituida. '$VARNAME'='$VALUE'"
		require_path "$VALUE"
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
	echo "$(date +%Y%m%d%H%M%S)"
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
	define APP_TYPE "$1"
	call "after_global_variables"
}

help_variables() {
	call "before_help_variables"
	define COMMANDS "start|pre_start|post_stop|start_only"	
	call "after_help_variables"
}

help() {
	print "Usage: $SCRIPT_NAME ($COMMANDS) APPLICATION NAME"
}

main() {
	call help_variables
	define ACTION $1
	shift
	case $ACTION in
		start) 
			trap "call 'post_stop' $*" 0 SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM
			call "setup" $*
			call "pre_start" $*
			call "start" $*
		;; 
		# pre_start utilizado pelo Upstart para chamar somente o evento de pre_start
		pre_start) 
			call "setup" $*
			call "pre_start" $*
		;;
		# post_stop utilizado pelo Upstart para chamar somente o evento de post_stop
		post_stop) 
			call "setup" $*
			call "post_stop" $*
		;;
		# start_only utilizado pelo Upstart para chamar somente o evento de post_stop
		start_only)
			call "setup" $*
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

setup() {
	call "before_setup"
	call "global_variables" $*
	call "java_variables"
	call "log_variables"
	call "after_setup"
}

pre_start() {
	call "on_pre_start"
	call "pre_java_start"
}

start() {
	call "on_start"
	call "java_start"
}

before_post_stop(){
	define DATA_STOP $(eval date_now)
}

post_stop() {
	call "before_post_stop"
	call "on_post_stop"
	call "log_variables_on_stop"
}

#---------------------------------------
#- SECÃO DE FUNÇÕES PARA EXECUÇÃO JAVA -
#---------------------------------------
java_variables() {
	# Detectar a JDK caso esteja definido
	if [ ! -e "$JAVA_HOME/bin/javac" ]; then
		define_path JAVA_HOME $(cd "$(dirname "$(which javac)")/.." && pwd)
	fi

	# Detectar o MAVEN_HOME caso esteja definido
	define_once MAVEN_HOME "$MVN_HOME"
	define_once MAVEN_HOME "$M2_HOME"
	if [ ! -e "$MAVEN_HOME/bin/mvn" ]; then
		define_path MAVEN_HOME $(cd "$(dirname "$(which mvn)")/.." && pwd)
	fi
	define_path MAVEN_BIN "$MAVEN_HOME/bin/mvn"

	# Definir configuracoes do java
	define JAVA_OPTS "-Xmx512m -Xms512m"
	define JAVA_DEBUG "n"
	define JAVA_DEBUG_SUSPEND "n"
	define JAVA_DEBUG_PORT "8123"

	call "on_java_variables"
}

maven() {
	if [ "$JAVA_DEBUG" == "y" ]; then
		define JAVA_DEBUG_OPTS "-agentlib:jdwp=transport=dt_socket,server=y,suspend=$JAVA_DEBUG_SUSPEND,address=0.0.0.0:$JAVA_DEBUG_PORT"
		define MAVEN_OPTS "$JAVA_OPTS $JAVA_DEBUG_OPTS"
	else
		define MAVEN_OPTS "$JAVA_OPTS"
	fi

	export MAVEN_OPTS

	define JAVA_DEBUG n

	call $MAVEN_BIN $*
}

pre_java_start() {
	define MAVEN_PRE_JAVA_START "clean compile"
	call "on_pre_java_start"

	#compila os fontes
	call maven $MAVEN_PRE_JAVA_START
}

java_start() {
	define MAVEN_JAVA_START "-P$AMBIENTE tomcat:run"
	call "on_java_start"

	#executa o projeto
	call maven $MAVEN_JAVA_START
}

#---------------------------------------
#- SECÃO DE FUNÇÕES PARA EXECUÇÃO LOG -
#---------------------------------------
log_variables() {
	call "before_log_variables"
	define LOG_DIR "../logs"
	define DATA_START $(date_now)
	define LOG_ROTATE_CONF "$AMBIENTE.logrotate"
	call "after_log_variables"
}

log_variables_on_stop() {
	define LOG_FOLDER_NAME "$APP""_""$DATA_START""_""$DATA_STOP"
}

#Consertar o redirecionamento do erro do stderr pro stdout
log_writer() {
	contador=0;
	while read LINE; do
		echo "${LINE}"  >> $1
		contador=$(expr $contador + 1)
		if [ $contador -eq 1000 ]; then	
			logrotate $LOG_ROTATE_CONF
			contador = 0
			# do something here
		fi
	done
}

log_rotate_template_generator(){
	sed -e "s/LOG_FILE_NAME/$(echo $LOGS_DIR | sed -e 's/\//\\\//g')\/$APP.console.log/" ../../../common/logrotate.template > $LOG_ROTATE_CONF
}
echo "Inicio"
ALL_ARGUMENTS=$*
call 'main' $ALL_ARGUMENTS