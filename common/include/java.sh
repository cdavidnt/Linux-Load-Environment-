#---------------------------------------
#----- FUNÇÕES PARA EXECUÇÃO JAVA ------
#---------------------------------------
. $(cd $(dirname $0) && pwd)/../../common/include/global.sh $*

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
	define JAVA_OPTS "-Xmx512m -Xms512m -XX:MaxPermSize=256m"
	define JAVA_DEBUG "n"
	define JAVA_DEBUG_SUSPEND "n"
	define JAVA_DEBUG_PORT "8123"
	
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

	cd $APP_DIR && call $MAVEN_BIN $*
}

pre_java_start() {
	define MAVEN_PRE_JAVA_START "-Dapp.name=$APP -Dapp.dir=$APP_DIR clean compile"

	#compila os fontes
	call maven $MAVEN_PRE_JAVA_START
}

java_start() {
	define MAVEN_JAVA_START "-Dapp.name=$APP -Dapp.dir=$APP_DIR -P$AMBIENTE tomcat:run"

	#executa o projeto
	call maven $MAVEN_JAVA_START
}

add_on_event "variables" "java_variables"
add_on_event "on_pre_start" "pre_java_start"
add_on_event "on_start" "java_start"
