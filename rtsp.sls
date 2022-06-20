{% set rtsp = pillar.get('rtsp') %}

download and extract rtsp-server:
  archive.extracted:
    - name: /opt/rtsp-server
    - source: https://github.com/aler9/rtsp-simple-server/releases/download/{{ rtsp['version'] }}/rtsp-simple-server_{{ rtsp['version'] }}_linux_amd64.tar.gz
    - skip_verify: True
    - enforce_toplevel: False
    - user: root
    - group: root

add RTSP service file:
  file.managed:
    - name: /lib/systemd/system/rtsp.service
    - user: root
    - group: root
    - mode: 0777
    - require:
      - download and extract rtsp-server
    - contents: |
        [Unit]
        Description=RTSP Server service
        After=network.target
        StartLimitIntervalSec=0

        [Service]
        Type=simple
        Restart=always
        RestartSec=1
        ExecStart=/opt/rtsp-server/rtsp-simple-server

        [Install]
        WantedBy=multi-user.target

reload systemctl rtsp:
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /lib/systemd/system/rtsp.service
    - require:
      - add RTSP service file

RTSP Service:
  service.running:
    - name: rtsp
    - order: last
    - enable: true
    - require:
      - add RTSP service file