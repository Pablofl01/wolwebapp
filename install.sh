#!/bin/bash

if [ "$EUID" -ne 0 ] 
    then echo "Para poder realizar la instalación, debes ejecutar este script como root."
	exit
fi

BIND_ADDRESS='0.0.0.0'
PORT='3000'
PARENT_PATH='/srv'
WORKING_PATH='/srv/wolsimpleserver'
CERT_PATH=''
KEY_PATH=''

while getopts ":p:b:w:c:k: h" opt
do
    case $opt in
        h)  echo "Mostrar ayuda" ;;
        b)  BIND_ADDRESS=$OPTARG   ;;
        p)  PORT=$OPTARG  ;;
        w)  PARENT_PATH=${OPTARG%'/'}
            WORKING_PATH="$PARENT_PATH/wolsimpleserver"  ;;
        c)  CERT_PATH=$OPTARG  ;;
        k)  KEY_PATH=$OPTARG  ;;
        \?) echo "Opción no válida -$OPTARG." 
            exit 1  ;;
        :)  echo "La opción -$OPTARG require un argumento."
            exit 1  ;;
    esac
done
shift $((OPTIND-1))

if [ -n "$1" ]; then
    echo "Mostrar ayuda"
fi

echo "Comprobando las dependencias necesarias."
apt update
for check in git ethtool python3 python3-pip pyhton3-venv openssl
    do
        result=`dpkg-query -s $check 2>&1`
        if [[ "$result" == *"is not installed"* ]]; then
            apt-get -y install $check
        fi
    done

mkdir -p $PARENT_PATH
cd $PARENT_PATH
git clone https://github.com/Pablofl01/wolsimpleserver
cd $WORKING_PATH

if [[ $CERT_PATH == '' ]] || [[ $KEY_PATH == '' ]]; then
    openssl req -x509 -newkey rsa:4096 -nodes -out $WORKING_PATH/data/cert.pem -keyout $WORKING_PATH/data/key.pem
    CERT_PATH="$WORKING_PATH/data/cert.pem"
    KEY_PATH="$WORKING_PATH/data/key.pem"
fi

echo "Crenado entorno virutal de pyhton."
python3 -m venv /srv/wolsimpleserver

echo "Instalando librerías."
$WORKING_PATH/bin/pip3 install -r $WORKING_PATH/requirements.txt

echo
read -r -p "Introduce el nombre identificativo del servidor: " SERVER_NAME
read -r -p "Introduce el correo electrónico del primer administrador: " ADMIN_MAIL
while [ true ]
do
    read -r -s -p "Introduce la contraseña del primer administrador: " ADMIN_PASS
    echo
    read -r -s -p "Confirma la contraseña: " CONFIRM_ADMIN_PASS
    echo

    if [[ $ADMIN_PASS == $CONFIRM_ADMIN_PASS ]];then
        break;
    else
        echo "Las contraseñas no coinciden."
        echo
    fi
done

SECRET=$(openssl rand -hex 20)

sed -e "s/<SERVER_NAME>/'$SERVER_NAME'/g; s/<ADMIN_EMAIL>/$ADMIN_EMAIL/g; s/<SECRET>/$SECRET/g;" $WORKING_PATH/data/serverConfigExample.py > $WORKING_PATH/data/serverConfig.py
echo
echo "Configurando envío de mensajes por correo electrónico."
chmod +x $WORKING_PATH/configure_email.sh
$WORKING_PATH/configure_email.sh

ENV='development' ADMIN_MAIL=$ADMIN_MAIL ADMIN_PASS=$ADMIN_PASS $WORKING_PATH/bin/python3 $WORKING_PATH/wsgi.py

echo
echo "Configurando servicio."
sed -e "s/<WORKING_PATH>/${WORKING_PATH//\//\\/}/g; s/<CERT_PATH>/${CERT_PATH//\//\\/}/g; s/<KEY_PATH>/${KEY_PATH//\//\\/}/g; s/<BIND_ADDRESS>/$BIND_ADDRESS/g; s/<PORT>/$PORT/g; " $WORKING_PATH/wolsimpleserverExample.service > /etc/systemd/system/wolsimpleserver.service
echo
echo "Iniciando servicio."
systemctl enable wolsimpleserver.service
systemctl start wolsimpleserver.service
echo
echo "Instalación completada."
systemctl status wolsimpleserver.service