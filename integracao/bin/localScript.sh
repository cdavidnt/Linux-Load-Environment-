. $(cd $(dirname $0) && pwd)/../../common/include/globalScript.sh $*

on_java_variables(){
	define JAVA_HOME "/opt/hudson/data/tools/JDK_1.6.0_24"
}

main $*