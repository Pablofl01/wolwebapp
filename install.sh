#!/bin/bash

if [ "$EUID" -ne 0 ] 
    then echo "Para poder realizar la instalación, debes ejecutar este script como root."
	exit
fi

SEPARATOR="------------------"

BIND_ADDRESS='0.0.0.0'
PORT='3000'
PARENT_PATH='/srv'
WORKING_PATH="$PARENT_PATH/wolwebapp"
SERVER_MODE='standalone'
CERT_PATH=''
KEY_PATH=''

while getopts ":b:p:w:m:c:k: h" opt
do
    case $opt in
        h)  echo "Mostrar ayuda" ;;
        b)  BIND_ADDRESS=$OPTARG   ;;
        p)  PORT=$OPTARG  ;;
        w)  PARENT_PATH=${OPTARG%'/'}
            WORKING_PATH="$PARENT_PATH/wolwebapp"  ;;
        m)  SERVER_MODE=$OPTARG ;;
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
for check in git ethtool python3 python3-pip python3-venv openssl wakeonlan
    do
        result=`dpkg-query -s $check 2>&1`
        if [[ "$result" == "dpkg-query"* ]]; then
            apt-get -y install $check
        fi
    done

mkdir -p $PARENT_PATH
cd $PARENT_PATH
git clone https://github.com/Pablofl01/wolwebapp
cd $WORKING_PATH

if [[ $CERT_PATH == '' ]] || [[ $KEY_PATH == '' ]]; then
    echo $SEPARATOR
    echo "A continuación se solicitarán los datos para generar un certificado SSL autofirmado:"
    echo
    openssl req -x509 -newkey rsa:4096 -nodes -out $WORKING_PATH/data/cert.pem -keyout $WORKING_PATH/data/key.pem
    CERT_PATH="$WORKING_PATH/data/cert.pem"
    KEY_PATH="$WORKING_PATH/data/key.pem"
fi

echo
echo "Creando entorno virtual de python."
python3 -m venv $WORKING_PATH

echo
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

sed -e "s/<SERVER_NAME>/$SERVER_NAME/g; s/<ADMIN_EMAIL>/$ADMIN_EMAIL/g; s/<SECRET>/$SECRET/g;" $WORKING_PATH/data/serverConfigExample.py > $WORKING_PATH/data/serverConfig.py
echo
echo "Configurando envío de mensajes por correo electrónico."
chmod +x $WORKING_PATH/configure_email.sh
$WORKING_PATH/configure_email.sh

ENV='firstrun' ADMIN_MAIL=$ADMIN_MAIL ADMIN_PASS=$ADMIN_PASS $WORKING_PATH/bin/python3 $WORKING_PATH/wsgi.py

echo
echo "Configurando servicio."


if [[ $SERVER_MODE == 'standalone' ]]; then
    sed -e "s/<WORKING_PATH>/${WORKING_PATH//\//\\/}/g; s/<IS_CERT>/--certfile/g; s/<CERT_PATH>/${CERT_PATH//\//\\/}/g; s/<IS_KEY>/--keyfile/g; s/<KEY_PATH>/${KEY_PATH//\//\\/}/g; s/<BIND_ADDRESS>/$BIND_ADDRESS/g; s/<PORT>/443/g; s/<APP>/wsgi/g;" $WORKING_PATH/services/wolwebapp_part.service > /etc/systemd/system/wolwebapp_main.service

    sed -e "s/<WORKING_PATH>/${WORKING_PATH//\//\\/}/g; s/<IS_CERT>//g; s/<CERT_PATH>//g; s/<IS_KEY>//g; s/<KEY_PATH>//g; s/<BIND_ADDRESS>/$BIND_ADDRESS/g; s/<PORT>/80/g; s/<APP>/redirect/g;" $WORKING_PATH/services/wolwebapp_part.service > /etc/systemd/system/wolwebapp_proxy.service

    cp $WORKING_PATH/services/wolwebapp.target /etc/systemd/system/wolwebapp.target

    systemctl enable wolwebapp.target
    systemctl start wolwebapp.target
else
    sed -e "s/<WORKING_PATH>/${WORKING_PATH//\//\\/}/g; s/<IS_CERT>//g; s/<CERT_PATH>//g; s/<IS_KEY>//g; s/<KEY_PATH>//g; s/<BIND_ADDRESS>/$BIND_ADDRESS/g; s/<PORT>/$PORT/g; s/<APP>/main/g;" $WORKING_PATH/services/wolwebapp.service > /etc/systemd/system/wolwebapp.service

    systemctl enable wolwebapp.service
    systemctl start wolwebapp.service
fi

echo
echo "Instalación completada."
