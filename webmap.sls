{% set webmap = pillar['webmap'] %}

{% set FTSIP = salt['pillar.get']('freetakserver:FTSIP', '192.168.192.5') %}
{% set FTSAPIKEY = salt['pillar.get']('freetakserver:FTSAPIKEY') %}
{% set FTSAPIPORT = salt['pillar.get']('freetakserver:FTSAPIPORT', '19023') %}
{% set FTSCOTPORT = salt['pillar.get']('freetakserver:cotport', '8087') %}

download and extract webmap:
  archive.extracted:
    - name: /opt/webmap
    - source: https://github.com/FreeTAKTeam/FreeTAKHub/releases/download/v{{ webmap['version'] }}/FTS-webmap-telegramtak-linux-{{ webmap['version'] }}.zip
    - skip_verify: True
    - enforce_toplevel: False
    - user: root
    - group: root

add executable permission to FTH-Webmap:
  file.managed:
    - name: /opt/webmap/FTH-webmap-linux-0.2.5
    - mode: 0744
    - require:
      - download and extract webmap
      
add webmap service file:
  file.managed:
    - name: /lib/systemd/system/webmap.service
    - user: root
    - group: root
    - mode: 0750
    - require:
      - download and extract webmap
    - contents: |
        [Unit]
        Description=WebMap Server service
        After=network.target
        StartLimitIntervalSec=0

        [Service]
        Type=simple
        Restart=always
        RestartSec=1
        ExecStart=/opt/webmap/FTH-webmap-linux-0.2.5 /opt/webmap/webMAP_config.json

        [Install]
        WantedBy=multi-user.target

reload systemctl webmap:
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /lib/systemd/system/webmap.service
    - require:
      - add webmap service file

stop webmap configure:
  service.dead:
    - name: webmap

configure webmap server:
  file.managed:
    - name: /opt/webmap/webMAP_config.json
    - user: root
    - group: root
    - mode: 0644
    - contents: |
        {
          "FTH_FTS_URL": "{{ FTSIP }}",
          "FTH_FTS_API_Auth": "{{ FTSAPIKEY }}",
          "FTH_FTS_API_Port": {{ FTSAPIPORT }},
          "FTH_FTS_TCP_Port": {{ FTSCOTPORT }}
        } 
    - require:
      - stop webmap configure

WebMap Service:
  service.running:
    - name: webmap
    - order: last
    - enable: true
    - require:
      - add webmap service file
