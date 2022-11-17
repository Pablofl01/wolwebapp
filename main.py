from flask import Flask, render_template, request, redirect, url_for
from subprocess import call, run, PIPE
from markupsafe import escape
import json

app = Flask(__name__)

with open('./machines.json', 'r') as file:
    machines = json.load(file)

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'GET':
        with open('./machines.json', 'r') as file:
            machines = json.load(file)
        return render_template('machines.html', machines=machines)
    
    elif request.method == 'POST':
        new_machines = []
        for i in range(0,int((len(request.form)-1)/3)):
            if request.form[f"machine[{i}][name]"] != "" and request.form[f"machine[{i}][mac]"] != "" and request.form[f"machine[{i}][ip]"] != "":
                new_machines.append({"name": request.form[f"machine[{i}][name]"], "mac": request.form[f"machine[{i}][mac]"], "ip": request.form[f"machine[{i}][ip]"], "port": "7"})
        with open('./machines.json', 'w') as file:
            file.write(json.dumps(new_machines, ensure_ascii=False))
        return redirect(url_for('index'))

@app.route('/edit')
def machineEdit():
    with open('./machines.json', 'r') as file:
        machines = json.load(file)
    return render_template('editMachines.html', machines=machines)

@app.route('/wol/<int:machineId>', methods=['POST', 'GET'])
def wolMachine(machineId):
    if request.method != 'POST':
        return redirect(url_for('index'))
    result = run(['wakeonlan', '-p', machines[machineId]["port"], machines[machineId]["mac"]], stdout=PIPE, stderr=PIPE, universal_newlines=True)
    if result.stderr != '':
        return '<svg class="iconRed" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path d="M256 512c141.4 0 256-114.6 256-256S397.4 0 256 0S0 114.6 0 256S114.6 512 256 512zm0-384c13.3 0 24 10.7 24 24V264c0 13.3-10.7 24-24 24s-24-10.7-24-24V152c0-13.3 10.7-24 24-24zm32 224c0 17.7-14.3 32-32 32s-32-14.3-32-32s14.3-32 32-32s32 14.3 32 32z"/></svg>'
    else:
        return '<svg class="iconGreen" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 576 512"><path d="M544 0c17.7 0 32 14.3 32 32V480c0 17.7-14.3 32-32 32s-32-14.3-32-32V32c0-17.7 14.3-32 32-32zM416 96c17.7 0 32 14.3 32 32V480c0 17.7-14.3 32-32 32s-32-14.3-32-32V128c0-17.7 14.3-32 32-32zM320 224V480c0 17.7-14.3 32-32 32s-32-14.3-32-32V224c0-17.7 14.3-32 32-32s32 14.3 32 32zM160 288c17.7 0 32 14.3 32 32V480c0 17.7-14.3 32-32 32s-32-14.3-32-32V320c0-17.7 14.3-32 32-32zM64 416v64c0 17.7-14.3 32-32 32s-32-14.3-32-32V416c0-17.7 14.3-32 32-32s32 14.3 32 32z"/></svg>'

@app.route('/ping/<int:machineId>', methods=['POST', 'GET'])
def pingMachine(machineId):
    if request.method != 'POST':
        return redirect(url_for('index'))

    with open('./machines.json', 'r') as file:
        machines = json.load(file)
    result = run(['ping', '-c', '5' , machines[machineId]["ip"]], stdout=PIPE, stderr=PIPE, universal_newlines=True)
    if result.stderr != '':
        return '<svg class="iconRed" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path d="M256 512c141.4 0 256-114.6 256-256S397.4 0 256 0S0 114.6 0 256S114.6 512 256 512zm0-384c13.3 0 24 10.7 24 24V264c0 13.3-10.7 24-24 24s-24-10.7-24-24V152c0-13.3 10.7-24 24-24zm32 224c0 17.7-14.3 32-32 32s-32-14.3-32-32s14.3-32 32-32s32 14.3 32 32z"/></svg>'
    if '0 received' in result.stdout:
        #cambiar estado
        return '<svg class="iconRedX" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 512"><path d="M310.6 150.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L160 210.7 54.6 105.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3L114.7 256 9.4 361.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L160 301.3 265.4 406.6c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3L205.3 256 310.6 150.6z"/></svg>'
    else:
        return '<svg class="iconGreen" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 576 512"><path d="M544 0c17.7 0 32 14.3 32 32V480c0 17.7-14.3 32-32 32s-32-14.3-32-32V32c0-17.7 14.3-32 32-32zM416 96c17.7 0 32 14.3 32 32V480c0 17.7-14.3 32-32 32s-32-14.3-32-32V128c0-17.7 14.3-32 32-32zM320 224V480c0 17.7-14.3 32-32 32s-32-14.3-32-32V224c0-17.7 14.3-32 32-32s32 14.3 32 32zM160 288c17.7 0 32 14.3 32 32V480c0 17.7-14.3 32-32 32s-32-14.3-32-32V320c0-17.7 14.3-32 32-32zM64 416v64c0 17.7-14.3 32-32 32s-32-14.3-32-32V416c0-17.7 14.3-32 32-32s32 14.3 32 32z"/></svg>'
