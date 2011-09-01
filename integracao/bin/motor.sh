. $(cd $(dirname $0) && pwd)/../../common/include/java.sh $*

# Variaveis obrigatorias
app_variables(){
	define APPS_DIR "$SCRIPT_PATH/../apps"
	define APP "fastseguros-motor"
	define APP_DIR "$APPS_DIR/$APP"
}
on_java_variables(){
	define JAVA_HOME "/opt/hudson/data/tools/JDK_1.6.0_24"
}

add_on_event "variables" "app_variables"

main $*
