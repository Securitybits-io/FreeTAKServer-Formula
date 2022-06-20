{% set ftsui = pillar['ftsui'] %}

{% set APPIP = salt['pillar.get']('ftsui:APPIP', '0.0.0.0') -%}
{% set FTSIP = salt['pillar.get']('freetakserver:FTSIP', '192.168.192.5') -%}
{% set WEBMAPIP = salt['pillar.get']('ftsui:WEBMAPIP', '192.168.192.6') -%}
{% set FTSAPIKEY = salt['pillar.get']('freetakserver:FTSAPIKEY') -%}
{% set FTSWEBSOCKETKEY = salt['pillar.get']('freetakserver:FTSWEBSOCKETKEY') -%}

install freetak-ui:
  pip.installed:
    - pkgs:
      - FreeTAKServer-UI

replace FTSIP:
  file.replace:
    - name: /usr/local/lib/python3.8/dist-packages/FreeTAKServer-UI/config.py
    - pattern: IP = .*
    - repl: IP = "{{ FTSIP }}"
    - require:
      - install freetak-ui

replace APPIP:
  file.replace:
    - name: /usr/local/lib/python3.8/dist-packages/FreeTAKServer-UI/config.py
    - pattern: APPIP = .*
    - repl: APPIP = "{{ APPIP }}"
    - require:
      - install freetak-ui

replace WEBMAPIP:
  file.replace:
    - name: /usr/local/lib/python3.8/dist-packages/FreeTAKServer-UI/config.py
    - pattern: WEBMAPIP = .*
    - repl: WEBMAPIP = "{{ WEBMAPIP }}"
    - require:
      - install freetak-ui

replace APIKEY:
  file.replace:
    - name: /usr/local/lib/python3.8/dist-packages/FreeTAKServer-UI/config.py
    - pattern: APIKEY = .*
    - repl: APIKEY = "Bearer {{ FTSAPIKEY }}"
    - require:
      - install freetak-ui

replace WEBSOCKET:
  file.replace:
    - name: /usr/local/lib/python3.8/dist-packages/FreeTAKServer-UI/config.py
    - pattern: WEBSOCKETKEY = .*
    - repl: WEBSOCKETKEY = "{{ FTSWEBSOCKETKEY }}"
    - require:
      - install freetak-ui

add FTSUI service file:
  file.managed:
    - name: /lib/systemd/system/ftsui.service
    - user: root
    - group: root
    - mode: 0777
    - require:
      - install freetak-ui
    - contents: |
        [Unit]
        Description=FreeTAKServer UI service
        After=network.target
        StartLimitIntervalSec=0

        [Service]
        Type=simple
        Restart=always
        RestartSec=1
        ExecStart=/usr/bin/python3 /usr/local/lib/python3.8/dist-packages/FreeTAKServer-UI/run.py
        [Install]
        WantedBy=multi-user.target

reload systemctl ftsui:
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /lib/systemd/system/ftsui.service
    - require:
      - add FTSUI service file

FreeTAKServer-UI Service:
  service.running:
    - name: ftsui
    - order: last
    - enable: true
    - require:
      - add FTSUI service file
