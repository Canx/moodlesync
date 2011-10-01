#!/bin/bash
#######################################################################################
# MoodleSync 0.2 (alfa)
# Programmer: Ruben Cancho
#
# Uso: 
#       moodlesync.sh backup <lugar>
#       moodlesync.sh restore <copia_origen> <destino>
#       moodlesync.sh list
# TODO:
#       COPIA FRESCA
#       Como hacer lo de la copia fresca?
#       Crearemos un fichero llamado "status" que contenga siempre el lugar de la copia fresca,
#       que podrá ser: pen, casa, clase, etc...
#       Ej: si contiene "pen", solo se podrán hacer restores.
#           si contiene otro lugar, solo se podrán hacer backups de ese lugar.
#           Cada accion cambiará el estado del fichero. backup lugar -> status = pen. restore lugar -> status = lugar
#           Si no existe el fichero de status solo se permitirá hacer backup lugar, y se generará status = pen.
#######################################################
# CONFIG
#######################################################
file="moodlesync.conf"
shell_user="www-data"
user=`id -nu`

#######################################################

# Funcion de ayuda
usage() {
	echo "Error:" $1
	CMD_NAME="$(basename "$0")"
	echo "Usage: "${CMD_NAME}" backup <server>"
	echo "       "${CMD_NAME}" restore <saved server> <destination server>"
	echo "       "${CMD_NAME}" list"
	exit 1
}

error() {
   echo "Error:" $1
   exit 1
}

warning() {
   echo "Warning:" $1
}

# Function: get_config_list config_file
# Purpose : Print the list of configs from config file
get_config_list()
{
	typeset config_file=$1

	awk -F '[][]' '
	NF==3 && $0 ~ /^\[.*\]/ { print $2 }
	' ${config_file}
}

# Function : set_config_vars config_file config [var_prefix]
# Purpose  : Set variables (optionaly prefixed by var_prefix) from config in config file
set_config_vars()
{
	typeset config_file=$1
	typeset config=$2
	typeset var_prefix=$3
	typeset config_vars

	config_vars=$( 
	awk -F= -v Config="${config}" -v Prefix="${var_prefix}" '
	BEGIN { 
		Config = toupper(Config);
		patternConfig = "\\[" Config "]";
	}
	toupper($0)  ~ patternConfig,(/\[/ && toupper($0) !~ patternConfig)  { 
		if (/\[/ || NF <2) next;
		sub(/^[[:space:]]*/, "");
		sub(/[[:space:]]*=[[:space:]]/, "=");
		print Prefix $0;
	} ' ${config_file} )

	eval "${config_vars}"
}

# Comprueba si el status es el correcto para la orden.
#check_state() {
   
#   cat ./status | while read line;
   
#   echo "ESTADO:" $line
   # Si line = pen entonces solo restore
   #if [ "$line" = "pen" ]; then
   #   if [ "$1" = "backup" ]; then
     
#}

# Graba el nuevo estado
#save_state() {
#}

backup() {
   # TODO 1: Comprobar que se tienen los permisos adecuados (backup)
   # De momento ver si estamos en el grupo $shell_user

   # TODO 3: Hacer las comprobaciones de backup antes y preguntar si se quiere continuar a pesar de ello
   # Backup de mysql
   if [ -z $orig_user ]; then error "'user' variable not defined in [$2] section. Check $file file."; fi
   if [ -z $orig_passwd ]; then error "'password' variable not defined in [$2] section. Check $file file."; fi
   if [ -z $orig_db ]; then error "'db' variable not defined in [$2] section. Check $file file."; fi
	mysqldump -h 127.0.0.1 -u ${orig_user} --password=${orig_passwd} -C -Q -e -a ${orig_db} > /tmp/$dest.sql
   if [ $? -ne 0 ]; then error "Database server problem. Check mysqldump error message."; fi

   # TODO 2: Comprobar que no existe el fichero antes! Creamos un nombre pseudo-aleatorio?
	gzip /tmp/$dest.sql
   # TODO 2: Comprobar que realmente podemos copiar el archivo! (backup)
   # TODO 2: Antes de copiar comprobar que no existe otro antes, si existe hacemos log roll.
	cp /tmp/$dest.sql.gz ./moodlesync

   # Backup de moodledata
   if [ -z ${orig_moodledata} ]; then error "'moodledata' variable not defined in [$1] section. Check $file file."; fi   
	if [ ! -d ./moodlesync/data_${dest}/ ]; then sudo -u $shell_user mkdir ./moodlesync/data_${dest}; fi

   sudo -u $shell_user chmod 775 -R ${orig_moodledata%/}/ 2> /dev/null
   sudo -u $shell_user chmod 775 -R ./moodlesync/data_${dest}/ 2> /dev/null

   for i in `sudo -u $shell_user find ${orig_moodledata%/}/ 2> /dev/null`; do [ -w $i ] || error "$i is not writeable."; done
   for i in `sudo -u $shell_user find ./moodlesync/data_${dest}/ 2> /dev/null`;do [ -w $i ] || error "$i is not writeable."; done
   
   sudo -u $shell_user rsync -va ${orig_moodledata%/}/ ./moodlesync/data_${dest}/

   # Resources backup
   # TODO 1: Comprobar que se tienen los permisos adecuados para hacer rsync (backup resources)
   if [ ! -d ./moodlesync/res_${dest}/ ]; then sudo -u $shell_user mkdir ./moodlesync/res_${dest}; fi

   if [ -z ${orig_resources} ]; then
      warning "'resources' variable not defined in [$1] section. Resources backup not done!"
   else
	   echo "rsync -va ${orig_resources%/}.tgz ./moodlesync/res_${dest}/"   
   fi
}

restore() {
   # TODO 1: Comprobar que se tienen los permisos adecuados (restore)
   # De momento ver si estamos en el grupo $shell_user

   # TODO 3: Hacer las comprobaciones de restore antes y preguntar si se quiere continuar a pesar de ello
   # Restore de mysql
   if [ -z $dest_user ]; then error "'user' variable not defined in [$2] section. Check $file file."; fi
   if [ -z $dest_passwd ]; then error "'password' variable not defined in [$2] section. Check $file file."; fi
   if [ -z $dest_db ]; then error "'db' variable not defined in [$2] section. Check $file file."; fi
	# TODO 2: Comprobar que existe el fichero ${orig}.sql.gz
	# TODO 2: Comprobar donde está la copia fresca
   # TODO 2: Comprobar que realmente podemos copiar el archivo! (backup)	
   cp ./moodlesync/${orig}.sql.gz /tmp/
	gunzip /tmp/${orig}.sql.gz
	mysql -u${dest_user} -p${dest_passwd} ${dest_db} < /tmp/${orig}.sql
   if [ $? -ne 0 ]; then error "Database server problem. Check mysql error message."; fi

   # Restore moodledata
   
   if [ -z ${dest_moodledata} ]; then error "'moodledata' variable not defined in [$2] section. Check $file file."; fi 
   # TODO 1: Comprobar que se tienen los permisos adecuados para hacer rsync (restore moodledata)
   #sudo -u $shell_user chgrp -R $shell_user ./moodlesync/data_${orig}/

   sudo -u $shell_user chmod 775 -R ${dest_moodledata%/}/
   sudo -u $shell_user chmod 775 -R ./moodlesync/data_${orig}/
	sudo -u $shell_user rsync -va ./moodlesync/data_${orig}/ ${dest_moodledata%/}/
   # TODO 1: Volvemos a dejar los permisos y grupo del usuario
   #chgrp -R $user ./moodlesync/data_${orig}/
   
   # Resources restore
   # TODO 1: Comprobar que se tienen los permisos adecuados para hacer rsync (restore resources)
   if [ -z ${dest_resources} ]; then
      warning "'resources' variable not defined in [$2] section. Resources not restored!"
   else
	   echo "rsync -va ./moodlesync/data_${orig}/ ${dest_resources%/}/"
   fi
}

# Comprobamos que la seccion pasada por parametro existe
check_section() {
	for cfg in $(get_config_list ${file})
	do
		if [ "${cfg}" = "$1" ]; then
			placeok=1
		fi
	done

	if [ -z "$placeok" ] ; then error "'$1' configuration not found. Check moodlesync.conf file"; fi
}

# Vamos a meter aqui todas las comprobaciones de la linea de comandos.
check_command() {
	if [ -z "$1" ]; then	usage "Comand parameter missing"; fi

	case $1 in
		backup)
			if [ -z "$2" ]; then usage "Second parameter missing"; fi
			check_section $2
			dest=$2
			;;
		restore)
			# Comprobamos que en modo "restore" existe el 3er parametro y que está en el fichero de configuracion.
			if [ -z "$2" ]; then usage "Second parameter missing"; fi
			if [ -z "$3" ]; then	usage "Destination server missing"; fi
			check_section $2
			check_section $3
			orig=$2
			dest=$3
			;;
		list)
			;;
		*)
			usage "First parameter incorrect"
			;;
	esac
}

#################### MAIN ###############################

# Depuracion activada
# set -x

check_command $1 $2 $3

# comprobamos que exista el directorio primero		
if [ ! -d moodlesync ]; then sudo -u $shell_user mkdir moodlesync; fi

# TODO 3: comprobar el estado de la copia maestra para avisar en caso de incongruencia.
#check_state $action

case $1 in
	backup)
		set_config_vars ${file} $2 "orig_"
		backup $2
		;;
	restore)
		set_config_vars ${file} $3 "dest_"
		restore $2 $3 
		;;
	list)
		echo "Configured servers: "$(get_config_list ${file})
		;;
	*)
		usage "First parameter incorrect"
		;;
esac
