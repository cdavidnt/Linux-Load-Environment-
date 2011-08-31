#---------------------------------------
#----- FUNÇÕES PARA EXECUÇÃO JAVA ------
#---------------------------------------
. $(cd $(dirname $0) && pwd)/../../common/include/java.sh $*

java_variables() {
	# Detectar a JDK caso esteja definido
	if [ ! -e "$JAVA_HOME/bin/javac" ]; then
		define_path JAVA_HOME $(cd "$(dirname "$(which javac)")/.." && pwd)
	fi

	# Detectar o MAVEN_HOME caso esteja definido
	define_once MAVEN_HOME "$MVN_HOME"
	define_once MAVEN_HOME "$M2_HOME"
	if [ ! -e "$MAVEN_HOME/bin/mvn" ]; then
		trace "nao existe"
		define_path MAVEN_HOME $(cd "$(dirname "$(which mvn)")/.." && pwd)
	fi
	define_path MAVEN_BIN "$MAVEN_HOME/bin/mvn"

	# Definir configuracoes do java
	define JAVA_OPTS "-Xmx512m -Xms512m -XX:MaxPermSize=256m"
	define JAVA_DEBUG "n"
	define JAVA_DEBUG_SUSPEND "n"
	define JAVA_DEBUG_PORT "8123"
	
	# Variaveis de aplicativo
	define APPS_DIR "$SCRIPT_PATH/../apps"
	define APP_TYPE "$1"
	define APP "fastseguros-"$APP_TYPE
	define APP_DIR "$APPS_DIR/$APP"
	
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

	cd $APP_DIR && call_redirect $MAVEN_BIN $*
}

pre_java_start() {
	define MAVEN_PRE_JAVA_START "-Dapp.name=$APP -Dapp.dir=$APP_DIR clean compile"
	call "on_pre_java_start"

	#compila os fontes
	call maven $MAVEN_PRE_JAVA_START
}

java_start() {
	define MAVEN_JAVA_START "-Dapp.name=$APP -Dapp.dir=$APP_DIR -P$AMBIENTE tomcat:run"
	call "on_java_start"

	#executa o projeto
	call maven $MAVEN_JAVA_START
}
