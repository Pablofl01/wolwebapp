from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import smtplib
import os

try:
    import data.serverConfig as config
except:
    print("No se ha definido un fichero de configuración para el envío de correo.")

def sendMail(to, subject, message):
    try:
        config
    except:
        return 1

    if (message is None):
        print("No se ha definido un mensaje.")
        return 2
    
    msg = MIMEMultipart()

    msg['From'] =  f'{config.MAIL_NAME} <{config.MAIL_USER}>'
    msg['To'] = to
    msg['Subject'] = subject
    
    msg.attach(MIMEText(message, 'html'))
    
    server = smtplib.SMTP(f'{config.MAIL_SERVER}:{config.MAIL_PORT}')
    server.starttls()
    try:
        server.login(config.MAIL_USER, config.MAIL_PASS)
    except:
        print("Error al iniciar sesión en el servidor.")
        return 3
    
    try:
        server.sendmail(msg['From'], msg['To'], msg.as_string())
    except:
        print("Error al enviar el mensaje.")
        return 4

    server.quit()

    return 0

def buildMessage(template, fields = {}):
    try:
        with open(f'{os.path.dirname(__file__)}/templates/{template}.html') as f:
            content = f.read()
            for field in fields.keys():
                content = content.replace(field, fields[field])

            return content
    except:
        print("Fallo al generar el mensaje.")
        return None