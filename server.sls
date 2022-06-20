#Package.freetakserver init.sls
{% set takserver = pillar['freetakserver'] %}

install dependencies:
  pkg.installed:
    - pkgs:
      - python3-pip
      - python3-dev
      - python3-setuptools
      - python3-gevent
      - python3-lxml
      - build-essential
      - libcairo2-dev
      - mlocate
      - zip

install tak dependencies:
  pip.installed:
    - pkgs:
      - wheel
      - pyopenssl
      - flask_login
      - itsdangerous==2.0.1
      - markupsafe==2.0.1
    - require:
      - install dependencies

install takserver:
  pip.installed:
    - name: FreeTAKServer
    - require:
      - install tak dependencies

add takserver service file:
  file.managed:
    - name: /lib/systemd/system/takserver.service
    - user: root
    - group: root
    - mode: 0777
    - require:
      - install takserver
    - contents: |
        [Unit]
        Description=FreeTAK Server service
        After=network.target
        StartLimitIntervalSec=0

        [Service]
        Type=simple
        Restart=always
        RestartSec=1
        ExecStart=/usr/bin/python3 -m FreeTAKServer.controllers.services.FTS \
          -CoTIP {{ takserver['cotip'] | default('0.0.0.0') }} \
          -CoTPort {{ takserver['cotport'] | default(8087) }} \
          -SSLCoTIP {{ takserver['sslcotip'] | default('0.0.0.0') }} \
          -SSLCoTPort {{ takserver['sslcotport'] | default(8089) }} \
          -DataPackageIP {{ takserver['datapackageip'] | default(takserver['FTSIP']) }} \
          -DataPackagePort {{ takserver['datapackageport'] | default(8080) }} \
          -SSLDataPackageIP {{ takserver['ssldatapackageip'] | default(takserver['FTSIP']) }} \
          -SSLDataPackagePort {{ takserver['ssldatapackageport'] | default(8443) }} \
          -RestAPIIP {{ takserver['restapiip'] | default('0.0.0.0') }} \
          -RestAPIPort {{ takserver['restapiport'] | default(19023) }} \
          -AutoStart {{ takserver['autostart'] | default(False) }}

        [Install]
        WantedBy=multi-user.target

service.systemctl_reload:
  module.run:
    - onchanges:
      - file: /lib/systemd/system/takserver.service
    - require:
      - add takserver service file

replace first_start:
  file.replace:
    - name: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/controllers/configuration/MainConfig.py
    - pattern: first_start.*
    - repl: first_start = False
    - require:
      - install takserver

/opt/FTSConfig.yaml:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - require:
      - install takserver
    - contents: | 
        System:
          FTS_SECRET_KEY: {{ takserver['FTSSECRETKEY'] }}
        Addresses:
          FTS_DP_ADDRESS: {{ takserver['FTSIP'] | default('192.168.192.5') }}
          FTS_USER_ADDRESS: {{ takserver['FTSIP'] | default('192.168.192.5') }}
          FTS_COT_PORT: {{ takserver['FTSCOTPORT'] | default('8087') }}
          FTS_SSLCOT_PORT: {{ takserver['FTSSSLCOTPORT'] | default('8089') }}
          FTS_API_PORT: {{ takserver['FTSAPIPORT'] | default('19023') }}
          FTS_FED_PORT: {{ takserver['FTSFEDPORT'] | default('9000') }}
          FTS_API_ADDRESS: {{ takserver['FTSAPIIP'] | default('0.0.0.0') }}
        FileSystem:
          FTS_DB_PATH: {{ takserver['FTSDBPATH'] | default('/opt/FTSDataBase.db') }}
          FTS_LOGFILE_PATH: {{ takserver['FTSLOGPATH'] | default('/var/log') }}
          #FTS_COT_TO_DB: True
          FTS_MAINPATH: /usr/local/lib/python3.8/dist-packages/FreeTAKServer
          FTS_CERTS_PATH: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs
          FTS_EXCHECK_PATH: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/ExCheck
          FTS_EXCHECK_TEMPLATE_PATH: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/ExCheck/template
          FTS_EXCHECK_CHECKLIST_PATH: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/ExCheck/checklist
          FTS_DATAPACKAGE_PATH: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/FreeTAKServerDataPackageFolder
        Certs:
          FTS_CLIENT_CERT_PASSWORD: {{ takserver['FTSCERTPASSWORD'] | default('atakatak') }}
          FTS_WEBSOCKET_KEY: {{ takserver['FTSWEBSOCKETKEY'] }}
          FTS_SERVER_KEYDIR: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/server.key
          FTS_SERVER_PEMDIR: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/server.pem
          FTS_UNENCRYPTED_KEYDIR: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/server.key.unencrypted
          FTS_SERVER_P12DIR: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/server.p12
          FTS_CADIR: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/ca.pem
          FTS_CAKEYDIR: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/ca.key
          FTS_CRLDIR: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/FTS_CRL.json
          #FTS_TESTCLIENT_PEMDIR: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/Client.pem
          #FTS_TESTCLIENT_KEYDIR: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/Client.key
          FTS_FEDERATION_CERTDIR: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/server.pem
          FTS_FEDERATION_KEYDIR: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/server.key
          FTS_FEDERATION_KEYPASS: {{ takserver['FTSFEDPASS'] | default('demopassfed') }}

TAKServer Service:
  service.running:
    - name: takserver
    - order: last
    - enable: true
    - require:
      - add takserver service file

create user cert generator:
  file.managed:
    - name: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/controllers/userCertCreator.py
    - mode: 0644
    - user: root
    - group: staff
    - contents: |
        #!/usr/bin/env python3
        import certificate_generation
        certificate_generation.AtakOfTheCerts().bake(common_name="user")
        certificate_generation.generate_zip(user_filename='user' + '.p12')
    - require:
      - TAKServer Service

create user certs:
  cmd.run:
    - name: /usr/bin/python3 userCertCreator.py
    - cwd: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/controllers
    - creates: 
      - /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/ClientPackages/user.zip
    - require: 
      - create user cert generator

extract user datapackage:
  archive.extracted:
    - name: /opt/user/
    - source: /usr/local/lib/python3.8/dist-packages/FreeTAKServer/certs/ClientPackages/user.zip
    - user: root
    - group: root
    - enforce_toplevel: false
    - require: 
      - create user certs

################################################################
create iTAK folder:
  file.directory:
    - name: /opt/iTAK
    - user: root
    - group: root
    - dir_mode: 0644
    - file_mode: 0755
    
create iTAK www folder:
  file.directory:
    - name: /opt/iTAK/www
    - user: root
    - group: root
    - dir_mode: 0644
    - file_mode: 0755
    - require:
      - create iTAK folder
    
create iTAK cert folder:
  file.directory:
    - name: /opt/iTAK/cert
    - user: root
    - group: root
    - dir_mode: 0644
    - file_mode: 0755
    - require:
      - create iTAK folder

extract user certs to iTAK cert :
  cmd.run:
    - name: unzip -o -d /opt/iTAK/user/ /opt/user/*/user.zip
    - require: 
      - create iTAK folder

move certificates to iTAK cert folder:
  cmd.run:
    - name: cp /opt/iTAK/user/*/*.p12 /opt/iTAK/cert/
    - require:
      - create iTAK cert folder

create iTAK Manifest File:
  file.managed:
    - name: /opt/iTAK/cert/manifest.xml
    - mode: 0644
    - user: root
    - group: root
    - require:
      - create iTAK cert folder
    - contents: |
        <MissionPackageManifest version="2">
          <Configuration>
            <Parameter name="uid" value="51b3d5ab-3abe-42be-bebf-c8ef633a11b8"/>
            <Parameter name="name" value="iTAK_DP"/>
            <Parameter name="onReceiveDelete" value="true"/>
          </Configuration>
          <Contents>
            <Content ignore="false" zipEntry="cert/preference.pref"/>
            <Content ignore="false" zipEntry="cert/server.p12"/>
            <Content ignore="false" zipEntry="cert/test.p12"/>
          </Contents>
        </MissionPackageManifest>

create iTAK pref file:
  file.managed:
    - name: /opt/iTAK/cert/preference.pref
    - mode: 0644
    - user: root
    - group: root
    - require:
      - create iTAK cert folder
    - contents: |
        <?xml version='1.0' encoding='ASCII' standalone='yes'?>
        <preferences>
          <preference version="1" name="cot_streams">
            <entry key="count" class="class java.lang.Integer">1</entry>
            <entry key="description0" class="class java.lang.String">{{ takserver['servername'] }}</entry>
            <entry key="enabled0" class="class java.lang.Boolean">true</entry>
            <entry key="connectString0" class="class java.lang.String">192.168.192.5:8089:ssl</entry>
          </preference>
          <preference version="1" name="com.atakmap.app_preferences">
            <entry key="caLocation" class="class java.lang.String">cert/server.p12</entry>
            <entry key="caPassword" class="class java.lang.String">atakatak</entry>
            <entry key="clientPassword" class="class java.lang.String">atakatak</entry>
            <entry key="certificateLocation" class="class java.lang.String">cert/user.p12</entry>
          </preference>
        </preferences>

create iTAK archive:
  cmd.run:
    - name: zip /opt/iTAK/www/iTAK.zip *
    - cwd: /opt/iTAK/cert
    - require: 
      - create iTAK Manifest File
      - create iTAK pref file

create http serv systemd file:
  file.managed:
    - name: /lib/systemd/system/certserver.service
    - user: root
    - group: root
    - mode: 0777
    - require:
      - install takserver
      - create iTAK archive
    - contents: |
        [Unit]
        Description=iTAK Cert Server
        After=network.target
        StartLimitIntervalSec=0

        [Service]
        Type=simple
        Restart=always
        RestartSec=1
        ExecStart=/usr/bin/python3 -m http.server --directory /opt/iTAK/www/

        [Install]
        WantedBy=multi-user.target

reload iTAK Cert Server:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: /lib/systemd/system/certserver.service
    - require:
      - create http serv systemd file

iTAK Cert Server Service:
  service.running:
    - name: certserver
    - order: last
    - enable: true
    - require:
      - reload iTAK Cert Server

################################################################

sleep for 20 seconds:
  module.run:
    - name: test.sleep
    - length: 20
    - require:
      - TAKServer Service

{% if salt['pillar.get']('freetakserver:SystemUsers') %}
{% for user, values in salt['pillar.get']('freetakserver:SystemUsers').items() %}
remove {{values['uuid']}}:{{ values['name'] }} from table:
  sqlite3.row_absent:
    - db: /opt/FTSDataBase.db
    - table: SystemUser
    - where_sql: uid='{{ values['uuid'] }}'
    - require:
      - sleep for 20 seconds

add {{values['uuid']}}:{{ values['name'] }} to Database:
  sqlite3.row_present:
    - db: /opt/FTSDataBase.db
    - table: SystemUser
    - where_sql: uid='{{ values['uuid'] }}'
    - data:
        uid: {{ values['uuid'] }}
        name: {{ values['name'] }}
        token: {{ values['token'] }}
        password: {{ values['password'] }}
        group: {{ values['group'] }}
    - require: 
      - sleep for 20 seconds
{% endfor %}
{% endif %}

decode datapackage DP_Google_Mapsources:
  file.decode:
    - name: /opt/DP_Google_Mapsources.zip
    - encoding_type: base64
    - encoded_data: |
        UEsDBBQAAAAIAKCUQ1KuG/oOHAEAAB4CAAAVAAAATUFOSUZFU1QvbWFuaWZlc3QueG1slZLRS8Mw
        EMbfBf+H0PfaJEvWBLq9qOjLYKDv45pcS7BLR5oN519vOu0Q5gRfcnwf3C/fHVet3DC43q/BvEGL
        K/CuwSGSA4bRXmQ8W97eEFLd975x7T5ATPbJSuYaAmwxYiA+1UU2vhk5QLdP4qnv2y4Rd8PmYZ2R
        4lrT3tlzD5aWWpQsB+BlLjRAXlthcpQcpDRUUssnVFVcZhpjRvRxmD771uTD7R59DMdFZkuq5pRa
        hmwujFZ1UpbN6kYqRF1C8ZV783ysg7N379suI671fUjxGugG/DHKJV1RTRXMUAurhOBMNcYwLBuj
        JDdzrib6SwyI8b90TksuZhKVTlXXoMpxEs0BasEsO2d/xRDA+T/wp+VNm6qK369g+QlQSwMEFAAA
        AAgAoJRDUjQLqGbeAAAATwEAADIAAABkNzA4NjAwZDFlMTY0Yzk4Yjg2MGQxM2JmNThlZTk3YS9H
        b29nbGVfSHlicmlkLnhtbF2QsU7DMBBAZ/IVUUBMEKdMqNjugAQssNAubK5zci1sn+U4VVzUf8d1
        A0M9Pb8nnU5HV5M19R7CoNGxZtF2TQ1OYq+dYs1m/XL/2Kx4ReU4RLTvwn/iGCTw6oo6YYGLtn5F
        VAbqt7QNuqek6Jytdl+IlneU/OHJiqngwyLrmbOO2sA6eeDeKUr+f3PZ+F5E4B/o4BxnkfMYDN/F
        6IclITa2quzSSrRkH4lJYWDpbmcYuFth/dPEfm6mY8GUMZ3xkPFwpOQ0K4/cCvmtAo6uf0aDgV93
        5VFyGSpKLs/yC1BLAwQUAAAACACglENSt6F7U9sAAABNAQAAMgAAADgwOTA4YTNlOTRkODQ0MjE4
        ZmNjMWU3ZmM4NTJjNjI4L0dvb2dsZV9TdHJlZXQueG1sXZCxTsMwEEBn8hVRQEyQS7cKbHeoVCZY
        aBc21zm5EbbPsp0qKeq/46aBoZ6e35NOp2OrwZryiCF25Hi1qJuqRKeo7Zzm1W67eV5WK1Ew1cdE
        9l36T+qDQlHcMSctin1dvhFpg2VukcEkc7Sd+yKyomHwhxcrhwkXy6xnzjp1BrejR+GdZvD/m8vO
        tzKh+CCH1ziLnPtgxCElH18AbKr1tEmtyMIxgRlD5PbpYDi6R2n968B/HobzhGPG8YqnjKczg8us
        PHIv1bcO1Lt2TYaCuG+mx+A2FAxuj/ILUEsDBBQAAAAIAKCUQ1IxaQ9Q3AAAAE8BAAAzAAAAMjA3
        MjQzNWU4OTcyNDliYTg3NjAwZDkyYWFiNDFkMWEvR29vZ2xlX1RlcnJhaW4ueG1sXZCxTsMwFEVn
        8hVRQEw0L90qartDJZhgoV3YjPPkRth+luNUSVH/HdcNDPV0fI50ZZltRmvKI4a+I8erZd1UJTpF
        bec0r/a7l8Wq2oiCqaGPZN+k/6AhKBTFHXPSolB1+UqkDe4wBNk5BlmnbDv3SWRFw+APL1aOGZer
        pGdOOnZpYfIovNMM/m9z2ftWRhTv5PAaZ5HyEIw4xOj7ZwAba53fUiuycIxgptBz/3QwHN2jtH49
        8p+H8ZxxSjhd8ZTwdGZw2UqTX1J960CDa7dkKIj7Jh8Gt6FgcPstv1BLAQIUABQAAAAIAKCUQ1Ku
        G/oOHAEAAB4CAAAVAAAAAAAAAAAAAAAAAAAAAABNQU5JRkVTVC9tYW5pZmVzdC54bWxQSwECFAAU
        AAAACACglENSNAuoZt4AAABPAQAAMgAAAAAAAAAAAAAAAABPAQAAZDcwODYwMGQxZTE2NGM5OGI4
        NjBkMTNiZjU4ZWU5N2EvR29vZ2xlX0h5YnJpZC54bWxQSwECFAAUAAAACACglENSt6F7U9sAAABN
        AQAAMgAAAAAAAAAAAAAAAAB9AgAAODA5MDhhM2U5NGQ4NDQyMThmY2MxZTdmYzg1MmM2MjgvR29v
        Z2xlX1N0cmVldC54bWxQSwECFAAUAAAACACglENSMWkPUNwAAABPAQAAMwAAAAAAAAAAAAAAAACo
        AwAAMjA3MjQzNWU4OTcyNDliYTg3NjAwZDkyYWFiNDFkMWEvR29vZ2xlX1RlcnJhaW4ueG1sUEsF
        BgAAAAAEAAQAZAEAANUEAAAAAA==
  
decode datapackage DP-GEN-Bockaby:
  file.decode:
    - name: /opt/DP-GEN-Bockaby.zip
    - encoding_type: base64
    - encoded_data: |
        UEsDBBQAAAAIAEZ3N1LoUlo1VgIAAPQKAAAVAAAATUFOSUZFU1QvbWFuaWZlc3QueG1spZZNaxtB
        DIbvhf6HZe/qzGg+F5xAk4YeStpce9R8KJimdrGdQPvrK5ckFNqQ2fXFy4h335lHllazul7v9+vt
        5obKN7pt17RZc9sfhoe2O4bPRhzP374ZhtXldsPr2/sdHST8JyTBG9rR93Zou2Ejz7Px+DsOD3R3
        L4sPN/Dx6jNcfLn89P7i6ziol966X9fnlyqaZjFMEOOkwWlPkBJWKI0TWp0qk3+yWql/D3U856Ft
        DvunzR7Xw6/1j6vNYffzbLQxOwxJg8k6gCuxQDZVg/WZo8toKZHqEb0r28M4rG83252cnOlu38bH
        bV+h7HH/K2HqEeJlJt+itpUbZK8dOM4Zco4eSvGh8FTIo1E9ouVMPe6zmBxrjy2wpCYacBUtTOwd
        aNuCld2w5ah6RMuZetxnMdlmbOIUYHIUwUm+IIckNV5MYd0o55pVj+iE2utwn8WkybbojJFiriiG
        tsDkxdBX1D4WdsVk1SNaztTjPq+fKOrJT1LMoTUp5lCBmrSqmYgiYY5ci+oRndBPHe6zmBKFWqvx
        wDFJkmJjoJgMcM04TbZOTmvVI1rO1OM+i6mFFhJigcbaSpJ0PCYJoVRnIjOSRa96RMuZetznfSMy
        a406Q5ICkBGYDUiEwPjChBazFLnqEZ3wjehwn8VEtbQ4SQkXJPnjsSYZ64zQtDHJa4zGaNUjWs7U
        4z6vn9inUkKWCVeqGOajoZPhIIMuBF0wFemnDtEJ/dThPouJLVdXq4OoA8nFJEfICRskj1Vbm7VM
        PNUjWs7U4/4S0/PqeP1bqf/fbc9/A1BLAwQUAAAACABGdzdSHAQsxJIBAACKAgAATQAAADM3YjQy
        NjgwLTFiMDYtNGM3Yy1iMWQwLTM1YmY3NGIyM2E4YS8zN2I0MjY4MC0xYjA2LTRjN2MtYjFkMC0z
        NWJmNzRiMjNhOGEuY290fVLbauMwEH1f6D8IvU9sSb7IIW7JlhAK2TaQ7EtfgiwriVjFNraStt+2
        D/tJ/YVOnG4SKFQgMRfN0Zwzev/7b3T3unPkYNrO1lVO2SCkxFS6Lm21yener0FS0nlVlcrVlcnp
        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
        0kQmaMYyZSnaEilKITgTUQIsDDkljWpxGOvLU9PJbD4lT9PlipLWINN+Rg00eLeti70+BtbfJecj
        Lkdx/HLVqGr11h7MJbDvTGuRHTkenfGN8tuM3j+v1o+TxeLhabZeLp5XaAfn6Qbzyd10fhYqOCs1
        DvpvdPMBUEsDBBQAAAAIAEZ3N1JxmA70jgEAAIoCAABNAAAAMGEzZTc0MTEtMWJkMi00MzNjLTk1
        OGEtNWQyMDU3Y2Y0YzFiLzBhM2U3NDExLTFiZDItNDMzYy05NThhLTVkMjA1N2NmNGMxYi5jb3R9
        Ut1OwjAUvjfxHZreH7Z2fx1hGjSEmKCSgDfckNIVaCzbshXUZ/PCR/IVPAwFEhKbtDk/PV/P951+
        f371bt83lux03ZiyyCjr+JToQpW5KVYZ3bolCEoaJ4tc2rLQGf3QDb29ub7q6Z0u3KmS7yu3Js+o
        LwOdhIwBW+QcwiBQkEZCQpRzP0rUMlRsQYn7qBBtARuooIENBswGA9znDHwGPJiyoBuFXSZmbQO1
        +ydpD5X8Mrku3zK6hhUY3CXFxgnpVaXB1q1EyCjpxEkYIzAltlWAd4SIY5EkWCwRNz0sStS5Y88d
        7wCbayeNbW30VFk4qRxR0trGrBD6jv9dxbQ1xeuvCBKWMIQXuIeHXwknwCACJMs50kpjEaMZiZSl
        aAukKIKAsyCMgfk+olayxmHMT08N+sPRgDwNJlNKao1M2xlVUOHdusy3ah+YX0rOu1x0o2R21qis
        1drs9CmwbXRtkB3ZH412lXTrjN4/T+eP/fH44Wk4n4yfp2h7x+l6o/7dYHQUyjsq1fPab3TzA1BL
        AwQUAAAACABGdzdSPfBHmY0BAACIAgAATQAAADVhNzA5NTllLWI2ZWUtNGY2ZC1hZTA2LTE5YWE3
        YTJiN2ZkYy81YTcwOTU5ZS1iNmVlLTRmNmQtYWUwNi0xOWFhN2EyYjdmZGMuY290fVLdasIwFL4f
        7B1C7o9t0r9UrKIiMnCboLvxRmIbNSy2pY1ue7Zd7JH2CjvWTQVhgYTzk/PlfN/J9+dXp/e+M+Sg
        qloXeUJZy6VE5WmR6XyT0L1dg6CktjLPpClyldAPVdNe9/6uow4qt5dKfqzc6yyhgYzcOIgVrEKl
        wF+HGUjlhsBiKSPJV9E6SymxHyWirWAHJdSww4DeYYC7nIHLgHtz5rUDv83Eommgsv8kzamS3ya3
        xVtCt7ABjbug2DghnbLQ2LqRCBlErTDyvZAS0/DnLSFC7jOGpRJR49OiJL12zLXjnEAzZaU2jY1e
        WuRWppak0phabxB64P1dxbTR+euvBBLWMIYXGMLDr4AzYBAAUuUcScWhCNEMRMxitAUSFJ7Hmeej
        pK7LKSllhaNYXp4a9ceTEXkazeaUVAp5NhMqocS7VZHt02NgeSs4b3PRDqLFVaOySrf6oC6Bfa0q
        jezI8aiVLaXdJnT4PF8+9qfTh6fxcjZ9nqPtnGfrTPqD0eQslHNWquM0n6j7A1BLAwQUAAAACABG
        dzdSpq5VP5ABAACKAgAATQAAADhhNmRkZDE1LWY3ODItNDdlZi1hNzgxLWZkYjI5OTNkOTQwMC84
        YTZkZGQxNS1mNzgyLTQ3ZWYtYTc4MS1mZGIyOTkzZDk0MDAuY290fVLLauMwFN0X+g9C+xtb8ksK
        cUtaQiikbSCZTTdBteREVLGNrWSm39ZFP6m/MDdOJwkURmBxn8fnnquvj8/R7Z+tI3vTdraucsoG
        ISWmKmptq3VOd74EQUnnVaWVqyuT03fT0dub66uR2ZvKnzv5oXNndU6FSrXWLIEyExzizJSgMsGg
        1K9cykjLOMRS/94g2itsoYEOthiwWwzwkDMIGfBoyaJhEg+ZeOkJtP4/SXfs5D+Tm/p3TjewBotf
        TZE4IaOmtkjdKYRMskGaRZJlnBLXK8AHQiQR5wybFeLK46GkuHTcpRMcYbXxyrreRq+oK68KTwrl
        XGfXCH0X/yvFtLPV27cICkqYwi+4h4dvCRfAIAEclnMcS6YiRTMRkkm0BY4oooizKE6BhSEyb1SL
        y1idfzUZT2cT8jRZLClpDU7a76iBBmvbWu+KQ2D1U3I+5GKYyJcLoqotNnZvzoFdZ1qL05HD1Rnf
        KL/J6f3zcvU4ns8fnqarxfx5iXZw2m4wG99NZiehgpNSo6B/Rjd/AVBLAwQUAAAACABGdzdSypKh
        5pEBAACKAgAATQAAAGU2ZTY4MjJjLWVmMDMtNGYwNy1hZTAyLWNkNDE3ZmYyYTMyNS9lNmU2ODIy
        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
        iQIAADM3YjQyNjgwLTFiMDYtNGM3Yy1iMWQwLTM1YmY3NGIyM2E4YS8zN2I0MjY4MC0xYjA2LTRj
        N2MtYjFkMC0zNWJmNzRiMjNhOGEuY290UEsBAhQAFAAAAAgARnc3Uo3skiCSAQAAigIAAE0AAAAA
        AAAAAAAAAAAAhgQAADVlNzAzZGZlLWI1MDQtNGZiYi1iYjc1LWNjNTZjZjljYTUyMS81ZTcwM2Rm
        ZS1iNTA0LTRmYmItYmI3NS1jYzU2Y2Y5Y2E1MjEuY290UEsBAhQAFAAAAAgARnc3UuGvvJqSAQAA
        igIAAE0AAAAAAAAAAAAAAAAAgwYAADRmMDUyZTZmLWIxNzEtNGQyMy05ZjU0LTAzZTYzNWU3MmVi
        Ny80ZjA1MmU2Zi1iMTcxLTRkMjMtOWY1NC0wM2U2MzVlNzJlYjcuY290UEsBAhQAFAAAAAgARnc3
        Up7HPkmSAQAAigIAAE0AAAAAAAAAAAAAAAAAgAgAADNlMTM4Zjg2LTk0YTctNDNkZi1iNjhhLThj
        MWNmMGVhYmJkYi8zZTEzOGY4Ni05NGE3LTQzZGYtYjY4YS04YzFjZjBlYWJiZGIuY290UEsBAhQA
        FAAAAAgARnc3UnGYDvSOAQAAigIAAE0AAAAAAAAAAAAAAAAAfQoAADBhM2U3NDExLTFiZDItNDMz
        Yy05NThhLTVkMjA1N2NmNGMxYi8wYTNlNzQxMS0xYmQyLTQzM2MtOTU4YS01ZDIwNTdjZjRjMWIu
        Y290UEsBAhQAFAAAAAgARnc3Uj3wR5mNAQAAiAIAAE0AAAAAAAAAAAAAAAAAdgwAADVhNzA5NTll
        LWI2ZWUtNGY2ZC1hZTA2LTE5YWE3YTJiN2ZkYy81YTcwOTU5ZS1iNmVlLTRmNmQtYWUwNi0xOWFh
        N2EyYjdmZGMuY290UEsBAhQAFAAAAAgARnc3UqauVT+QAQAAigIAAE0AAAAAAAAAAAAAAAAAbg4A
        ADhhNmRkZDE1LWY3ODItNDdlZi1hNzgxLWZkYjI5OTNkOTQwMC84YTZkZGQxNS1mNzgyLTQ3ZWYt
        YTc4MS1mZGIyOTkzZDk0MDAuY290UEsBAhQAFAAAAAgARnc3UsqSoeaRAQAAigIAAE0AAAAAAAAA
        AAAAAAAAaRAAAGU2ZTY4MjJjLWVmMDMtNGYwNy1hZTAyLWNkNDE3ZmYyYTMyNS9lNmU2ODIyYy1l
        ZjAzLTRmMDctYWUwMi1jZDQxN2ZmMmEzMjUuY290UEsBAhQAFAAAAAgARnc3UhvMkE2OAQAAigIA
        AE0AAAAAAAAAAAAAAAAAZRIAADNiZjAwMjBiLTg3MDktNDBiMS1iZjBhLTE1Y2ZhMjMyYjFiZC8z
        YmYwMDIwYi04NzA5LTQwYjEtYmYwYS0xNWNmYTIzMmIxYmQuY290UEsBAhQAFAAAAAgARnc3Ujkf
        ryOPAQAAigIAAE0AAAAAAAAAAAAAAAAAXhQAAGFkY2U3OTZkLWMyYTItNDJkOC04OGYyLWUwMTE4
        NTAyNzExMC9hZGNlNzk2ZC1jMmEyLTQyZDgtODhmMi1lMDExODUwMjcxMTAuY290UEsBAhQAFAAA
        AAgARnc3Ug7PIiKZAQAAowIAAE0AAAAAAAAAAAAAAAAAWBYAADhmNThjYzZiLWNjY2QtNDJiOC04
        ODQ0LTA1MjE2NjBjMjhjMC84ZjU4Y2M2Yi1jY2NkLTQyYjgtODg0NC0wNTIxNjYwYzI4YzAuY290
        UEsBAhQAFAAAAAgARnc3UsM4ZPWEAQAAcgIAAE0AAAAAAAAAAAAAAAAAXBgAAGYzZmQ0ZGQ0LTcw
        NmEtNGNiNy1iODJlLTg1MmQwMzNiMDJlYi9mM2ZkNGRkNC03MDZhLTRjYjctYjgyZS04NTJkMDMz
        YjAyZWIuY290UEsFBgAAAAANAA0ABwYAAEsaAAAAAA==
        
decode datapackage DP-NOGO-RODJENAS:
  file.decode:
    - name: /opt/DP-NOGO-RODJENAS.zip
    - encoding_type: base64
    - encoded_data: |
        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
        Bxd0nqbrLH7A5UOuHJccJHzMSWo0YRsnDd3xE5li9MYBSM12OKW4Ug+3xSIEiL17CRiycXmZ8T2O
        At84mp+8846dvty18rDtq8O6zZtfUEsDBBQAAAAIAGFVZFICEIOsegEAAN0FAABNAAAANWQ1NWNi
        NTQtZjY3OC00OWIwLTg2MmItMTc4ZWEyNzBhOWExLzVkNTVjYjU0LWY2NzgtNDliMC04NjJiLTE3
        OGVhMjcwYTlhMS5jb3TtVEtz2yAQ/isM5yIDYnlkJOWQv9BTLx0sYYsxhoyEnObfl8h24j6S6bkT
        Trv7PViY2W3ufxwDOrlp9im2mFUUIxf7NPi4b/GSd0RjNGcbBxtSdC1+djO+7xp3cjG/6fiLbvFD
        i2EA6LcgyE4qTYTZUqIl3xKmtLNcUWsswyg/PxavhQxkVxJ/LAmnnBFaEyq+UnNXqzugFbBv6+1T
        /hgPN3rGfsPH9NTikTjcNY/Jl66DLXagKgDKa+CMgzCAUVg/QFRaMzB1LQ3jqpRHW8zN+WDU3ybh
        Ntl0zeCy9aFr+hSz7TPqbQiz3xfbasXnPKWDe0ghTehkw1LkRALUckV3PoRfsNKY5hykFCs+uaOd
        DvNLODq/H/OVRytK8Vv5+xL9K3aW2qkf/cl9hp/hfx8GHw9oHfTXIedUmi/nyaY14+dh+ZMnJJVw
        4SmhJLzDqxXV/MIzhSbe4TGplL7yuBbqrzxhDEh29eOaX5bJv77j5umb6wLarOu5+wlQSwMEFAAA
        AAgAYVVkUvr05JRyAQAAfAUAAE0AAAAwYjkwYjdkNS1iZDQ4LTRmYzQtYTlmNy1jZTYwMDA3NmZh
        OTYvMGI5MGI3ZDUtYmQ0OC00ZmM0LWE5ZjctY2U2MDAwNzZmYTk2LmNvdO1UzXLbIBB+FYZzkRfx
        n5GUQ18hp146WEIWYywyEnKbtw+R7MRNm9w7E067fD/LHj6q+9+ngM5umn0ca0wLwMiNbez8eKjx
        knqiMZqTHTsb4uhq/ORmfN9U7uzG9KYrX3SL72oMewN71Qmy77gmvG85saZXpHUSAJTsrZEYpafH
        7LWQjvS58afclFBSAowAfwBzx/RdCQWUP9bpU/ocDzd6St/hQ/xV44E43FSP0edXB5vthCqEAGok
        cOAco7CuzwutJZNcliCYNFlss7XZDkbtbRNum11TdS5ZH5qqjWOybUKtDWH2h2xbrPicpnh032OI
        EzrbsGQ5kSKPWdHeh/AHRqmhlEoNsOKTO9npOL+Ug/OHIV15ecuNsV3/XEb/ivEVsFM7+LP7Kr/K
        /6cMfjyiNa/XrDLKSv1tjahg1MCWur95QkupNp4CTZn6gAeqNHDhMQ6XFL3ncaMpZReeUFQD+8Dv
        3++7WWl3/SF26+/ZPANQSwMEFAAAAAgAYVVkUuFGPEFwAQAA2QQAAE0AAAAwZjhiNWQ5MC1hODll
        LTQ3OGEtYmVmMy1lYzljNTE4MzE4NDcvMGY4YjVkOTAtYTg5ZS00NzhhLWJlZjMtZWM5YzUxODMx
        ODQ3LmNvdO2U3U6sMBSFX6XptWX6S1sDeOEreHVuTiqUoZlOa6CM+vZ2OqOOZvQJJJDsxfrWphB2
        m7uXvQcHOy8uhhaSCkNgQx8HF7YtXNOIFARLMmEwPgbbwle7wLuusQcb0meOHnOrG1qIR/UoBo2R
        UdoiLpVBj3ZkyPa6F0QxoriEIL0+5V4rGtCYhdtnQTElCDOE+QPWt0zls5L1v/L0Of3u+4s8Id/8
        KT63cEIWds1TdHnV3uR2QlZCUE04VkIKKiDw5QPwSmmMGa21oJKTHDe5uT4dEPSXwl+KTdcMNhnn
        u6aPIZk+gd54v7htblsVf0lz3Nn76OMMDsavOY5qIVhd3NF5/8UjBEvK8oWLP9u9mXfLsZys207p
        ncMVPhGn2//X4D48Xgwz95M72L/yryyld2EHyjCcB4FRoQW7Of39jJGawascrY/TceZEFuIHTiiG
        VeGUllxzfp1jhHLJzhxXWNY/cNfXd/FKm/fh25StqXsDUEsDBBQAAAAIAGFVZFL/rK3aYAEAAMgC
        AABNAAAANTQ2NTI2YWMtMTYwNy00OTIxLWIwYzgtMjNkMGExNDEzNTUxLzU0NjUyNmFjLTE2MDct
        NDkyMS1iMGM4LTIzZDBhMTQxMzU1MS5jb3R9UtuO2yAQ/RXEc3GGu6ls70N/oU/7UlGbxCgEVjZO
        u3+/hOwl2zZFIM1wLsyM6B5+nwI6u2X1KfaYNoCRi2OafDz0eMt70mK0ZhsnG1J0PX52K34YOnd2
        MX/o2EW3+anHUijJlB0JVaCJMIySnzC2hPEJLBWUS0kxys9PxWsjE9mXxJ9KwqBQgRMQ38F85WWr
        RsNjfX3J/8fDjZ7SP/A5/erxTBweuqfkS9XBFjupGykMZ1JLLiQzGIU6ANG0WnNthGagdVHb4m2u
        C6PxNgm3yW7oJpetD0M3ppjtmNFoQ1j9obg2FV/zko7uWwppQWcbtiInSkquKrr3IXzCKAXNeDlQ
        8cWd7HJcL2Hw8YhqL+99cAbmSy1eqdbA1fJvHkho6ZWnmTTC3OFxasQrrwUpqLzDUwAaXv0klfSu
        3z/rm50/zPmtX2gAbq5/bNG/Y6ICdhlnf3aXcPc27F39icMLUEsDBBQAAAAIAGFVZFLbT0xPaQEA
        AFUEAABNAAAAMTdkYTM2NmEtNDZjMS00ODFiLTgyZDMtZjBmZWE3YjA5NzkyLzE3ZGEzNjZhLTQ2
        YzEtNDgxYi04MmQzLWYwZmVhN2IwOTc5Mi5jb3TtVMtSwyAU/ZUMa0mB8OykceEvuHLj0IQ0TCk4
        Can691K0D53WtQtZ3ct58DpDff+2c8XejJMNfgVwiUBhfBs66zcrMMceSlBMUftOu+DNCrybCdw3
        tdkbH886ctDNtksOotMV5xpS3mJIJV5DSboK9qg3WqyREoqAIr6/JK8ZdrBPjd2lhiCCIaogoo9I
        LSu1JLzE6imvPsbfcXehx/gHPoTXFRigAU39EmzatdPJjomSUSk4YVxIXKVTunwBtJRCEIUlFlQp
        luQ6mavPAYr2snGXzaKpOxO1dU3dBh91G4tWOzfZTbItMz7FMWzNQ3BhLPbazUkOOWMVz2hvnfuG
        YcwE46TiMuOj2elxOx3KwdjNEI88VCIEztPPs7cnjGZAj+1g9+a//AOls35b5CCeQqikUnc5eVyl
        R8fgOo9RpvjdV0IJI/wGT1AijjyBEGc3eOoQ/i9eRZS8xbu+v4sjLY7BX+RvofkAUEsDBBQAAAAI
        AGFVZFIo/dGuhQEAAAUGAABNAAAANGJjZmNlMjktNTQ0OS00NTFiLTlmMGItNDFhNzIzN2EyZTRh
        LzRiY2ZjZTI5LTU0NDktNDUxYi05ZjBiLTQxYTcyMzdhMmU0YS5jb3TtVM1u4yAQfhXEuTiA+a1s
        97CvsKe9VMTGMQqBysbZ7dsvdpI2u6r7AFU5zcz3M4A0Uz39OXlwtuPkYqghKTAENrSxc+FQwzn1
        SEEwJRM642OwNXy1E3xqKnu2Ib3r6KKbXVdDtm/71lKNOGMaMU72SPd4jxgxkpbSUMsMBOn1JXvN
        qEN9TtwpJxRTgnCJMPuJ9SPDj0QVUv5au4/pc9zf6Qn5Dx/i7xoOyMKmeoku39qbbMdlwZlSkivF
        taYCAr9+ACuUFCWTigtKylweTDbXlwNBe5/4+2TXVJ1NxvmmamNIpk2gNd5P7pBtixWf0hiP9kf0
        cQRn4+csR4LzpUtGe+f9PxghkpWl5oqt+GhPZjxOSzhYdxjSjYcLjOF7+XkO7g27SM3YDu5sv8Pv
        8MuH3oUjWAf9OuSallSoh8tkk2Wo4Ic8pZmiV57EWAi1wZNSKHn1E8v+2OAJKTm98YSWdIPHqeTl
        7X4Kc/0xT2NN2ZXHGdd8o+/Ge+++aHdbVLt1jTd/AVBLAwQUAAAACABhVWRSkI2pZXQBAAAxBQAA
        TQAAAGEyM2UzNjkxLTM5NGEtNGU5NC1iMGZhLTY0ZDRkYmNjMzljMy9hMjNlMzY5MS0zOTRhLTRl
        OTQtYjBmYS02NGQ0ZGJjYzM5YzMuY2907ZTNctsgEMdfRcO5yHx/ZCTl0FfIKZcMQdhijCEjIbd5
        +xBcN06a5NabOe3u77/LwrB0t78PoTm6efEp9gC3CDQu2jT6uOvBmrdQgWbJJo4mpOh68OwWcDt0
        7uhifssjr3mrH3tgCHVUaAypZgYypxl8RFsDBRvZ+Ggt1ZaCJj8/lVorHOG2OP5QHIIIhohCxO6Q
        vmHohrOWo/u6+5y/5+EiH+MPfEq/ejBBB4buKfnSdTClHJctZ0RKSglHHJVThnoBrFVSEkKpKJiV
        8GRKcX1aoLGXTrh0NkM3umx8GDqbYjY2N9aEsPhdKdtWvuQ57d3PFNLcHE1YSzoUnFNR6daH8I5h
        JKmQgihV+ewOZt4vr+bk/G7KZx1qEQJv4Yc1+r+MVWBmO/mju5pX87+awcd9U4fsPGBaCKp+1Kni
        iiB1eo//6CjBkrCTThGMOP9cR7jikv/RMY61/EJHCdX4pBMMI4y/0H3e38WRNueh3tQvb3gBUEsB
        AhQAFAAAAAgAYVVkUqRnF/o0AgAAIgoAABUAAAAAAAAAAAAAAAAAAAAAAE1BTklGRVNUL21hbmlm
        ZXN0LnhtbFBLAQIUABQAAAAIAGFVZFI15xliiwEAAGgDAABNAAAAAAAAAAAAAAAAAGcCAABkYmJi
        MWU4MC1kYzNmLTRlZGItOTMyNi00ZThiMGNiMTg3YjUvZGJiYjFlODAtZGMzZi00ZWRiLTkzMjYt
        NGU4YjBjYjE4N2I1LmNvdFBLAQIUABQAAAAIAGFVZFJVxbB4pAEAAMAFAABNAAAAAAAAAAAAAAAA
        AF0EAAA3MWVhMmEyMC01NzJlLTRiNzAtOGU5Yy03MWQ1MmJjMGNhODMvNzFlYTJhMjAtNTcyZS00
        YjcwLThlOWMtNzFkNTJiYzBjYTgzLmNvdFBLAQIUABQAAAAIAGFVZFL9G4OBggEAAIwFAABNAAAA
        AAAAAAAAAAAAAGwGAAAxODVmZWFmZC05ZDFhLTQ4OGUtOWExYS0yOWYyNWFkZDU0OTgvMTg1ZmVh
        ZmQtOWQxYS00ODhlLTlhMWEtMjlmMjVhZGQ1NDk4LmNvdFBLAQIUABQAAAAIAGFVZFKa25cYjwEA
        AAwGAABNAAAAAAAAAAAAAAAAAFkIAAA4NmUyZjNmYy1mNjhmLTQ1YjktODU4ZC1iM2Q5OTVkMTUw
        ZmUvODZlMmYzZmMtZjY4Zi00NWI5LTg1OGQtYjNkOTk1ZDE1MGZlLmNvdFBLAQIUABQAAAAIAGFV
        ZFICEIOsegEAAN0FAABNAAAAAAAAAAAAAAAAAFMKAAA1ZDU1Y2I1NC1mNjc4LTQ5YjAtODYyYi0x
        NzhlYTI3MGE5YTEvNWQ1NWNiNTQtZjY3OC00OWIwLTg2MmItMTc4ZWEyNzBhOWExLmNvdFBLAQIU
        ABQAAAAIAGFVZFL69OSUcgEAAHwFAABNAAAAAAAAAAAAAAAAADgMAAAwYjkwYjdkNS1iZDQ4LTRm
        YzQtYTlmNy1jZTYwMDA3NmZhOTYvMGI5MGI3ZDUtYmQ0OC00ZmM0LWE5ZjctY2U2MDAwNzZmYTk2
        LmNvdFBLAQIUABQAAAAIAGFVZFLhRjxBcAEAANkEAABNAAAAAAAAAAAAAAAAABUOAAAwZjhiNWQ5
        MC1hODllLTQ3OGEtYmVmMy1lYzljNTE4MzE4NDcvMGY4YjVkOTAtYTg5ZS00NzhhLWJlZjMtZWM5
        YzUxODMxODQ3LmNvdFBLAQIUABQAAAAIAGFVZFL/rK3aYAEAAMgCAABNAAAAAAAAAAAAAAAAAPAP
        AAA1NDY1MjZhYy0xNjA3LTQ5MjEtYjBjOC0yM2QwYTE0MTM1NTEvNTQ2NTI2YWMtMTYwNy00OTIx
        LWIwYzgtMjNkMGExNDEzNTUxLmNvdFBLAQIUABQAAAAIAGFVZFLbT0xPaQEAAFUEAABNAAAAAAAA
        AAAAAAAAALsRAAAxN2RhMzY2YS00NmMxLTQ4MWItODJkMy1mMGZlYTdiMDk3OTIvMTdkYTM2NmEt
        NDZjMS00ODFiLTgyZDMtZjBmZWE3YjA5NzkyLmNvdFBLAQIUABQAAAAIAGFVZFIo/dGuhQEAAAUG
        AABNAAAAAAAAAAAAAAAAAI8TAAA0YmNmY2UyOS01NDQ5LTQ1MWItOWYwYi00MWE3MjM3YTJlNGEv
        NGJjZmNlMjktNTQ0OS00NTFiLTlmMGItNDFhNzIzN2EyZTRhLmNvdFBLAQIUABQAAAAIAGFVZFKQ
        jalldAEAADEFAABNAAAAAAAAAAAAAAAAAH8VAABhMjNlMzY5MS0zOTRhLTRlOTQtYjBmYS02NGQ0
        ZGJjYzM5YzMvYTIzZTM2OTEtMzk0YS00ZTk0LWIwZmEtNjRkNGRiY2MzOWMzLmNvdFBLBQYAAAAA
        DAAMAIwFAABeFwAAAAA=

set file permissions for DP_Google_Mapsources:
  file.managed:
    - name: /opt/DP_Google_Mapsources.zip
    - user: root
    - group: root
    - mode: "0755"
    - require:
      - decode datapackage DP_Google_Mapsources 

set file permissions for DP-GEN-Bockaby:
  file.managed:
    - name: /opt/DP-GEN-Bockaby.zip
    - user: root
    - group: root
    - mode: "0755"
    - require:
      - decode datapackage DP-GEN-Bockaby

set file permissions for DP-NOGO-RODJENAS:
  file.managed:
    - name: /opt/DP-NOGO-RODJENAS.zip
    - user: root
    - group: root
    - mode: "0755"
    - require:
      - decode datapackage DP-NOGO-RODJENAS

upload DP_Google_Mapsources to FreeTAKServer:
  cmd.run:
    - name: "/usr/bin/curl -XPOST -F assetfile=@DP_Google_Mapsources.zip -H 'Authorization: Bearer {{ takserver["FTSAPIKEY"] }}' http://127.0.0.1:19023/DataPackageTable?filename=DP_Google_Mapsources.zip&creator="
    - cwd: /opt
    - requires: 
      - set file permissions for DP_Google_Mapsources

upload DP-GEN-Bockaby to FreeTAKServer:
  cmd.run:
    - name: "/usr/bin/curl -XPOST -F assetfile=@DP-GEN-Bockaby.zip -H 'Authorization: Bearer {{ takserver["FTSAPIKEY"] }}' http://127.0.0.1:19023/DataPackageTable?filename=DP-GEN-Bockaby.zip&creator="
    - cwd: /opt
    - requires: 
      - set file permissions for DP-GEN-Bockaby

upload DP-NOGO-RODJENAS to FreeTAKServer:
  cmd.run:
    - name: "/usr/bin/curl -XPOST -F assetfile=@DP-NOGO-RODJENAS.zip -H 'Authorization: Bearer {{ takserver["FTSAPIKEY"] }}' http://127.0.0.1:19023/DataPackageTable?filename=DP-NOGO-RODJENAS.zip&creator="
    - cwd: /opt
    - requires: 
      - set file permissions for DP-NOGO-RODJENAS

{% if salt['pillar.get']('freetakserver:datapackages') %}
{% for datapackage, values in salt['pillar.get']('freetakserver:datapackages').items() %}
decode {{ datapackage }}:
  file.decode:
    - name: /opt/{{ datapackage }}.zip
    - contents_pillar: freetakserver:datapackages:{{ datapackage }}:data
    - encoding_type: base64
    - require:
      - extract user datapackage

set file permissions for {{ datapackage }}:
  file.managed:
    - name: /opt/{{ datapackage }}.zip
    - user: root
    - group: root
    - mode: "0755"
    - require:
      - decode {{ datapackage }} 

upload {{ datapackage }} to FreeTAKServer:
  cmd.run:
    - name: "/usr/bin/curl -XPOST -F assetfile=@{{ datapackage }}.zip -H 'Authorization: Bearer {{ takserver["FTSAPIKEY"] }}' http://127.0.0.1:19023/DataPackageTable?filename={{ datapackage }}.zip&creator="
    - cwd: /opt
    - requires: 
      - set file permissions for {{ datapackage }}
{% endfor %}
{% endif %}