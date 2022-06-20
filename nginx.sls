{% set nginx = pillar['nginx'] %}

install nginx dependencies:
  pkg.installed:
    - pkgs: 
        - apache2-utils

install_nginx:
  pkg.installed:
    - name: nginx
    - require:
        - install nginx dependencies

remove default symlink:
  file.absent:
    - name: /etc/nginx/sites-enabled/default
    - require:
      - pkg: nginx

{% if salt['pillar.get']('nginx:site-config') %}
  {%- for server, values in salt['pillar.get']('nginx:site-config').items() %}
create web config for {{ server }}:
  file.managed:
    - name: /etc/nginx/sites-available/{{ server }}.conf
    - user: root
    - group: root
    - mode: 0644
    - require:
      - pkg: nginx
    - contents: |
        server {
          listen               80;
          auth_basic           "{{ values['name'] | default('ZeroTAK') }}";

          location / {
            proxy_pass              http://{{ values['host'] }}:8000/tak-map/;
          }
        }

create symlink for {{ server }}:
  file.symlink:
    - name: /etc/nginx/sites-enabled/{{ server }}.conf
    - target: /etc/nginx/sites-available/{{ server }}.conf
    - force: True
    - require:
      - pkg: nginx

    {% if values['user'] is defined %}
create htpasswd for {{ server }}:
  cmd.run:
    - name: htpasswd -b -c /etc/nginx/.htpasswd {{ values['user'] }} {{ values['pass'] }}
    - creates: /etc/nginx/.htpasswd
    - require:
      - pkg: nginx
      
      {% set slack = pillar['slack'] %}
      {% if slack["post"] == True %}
post nginx credentials status for {{ server }}:
  slack.post_message:
    - channel: {{ slack["channel-name"] }}
    - from_name: {{ grains['host'] }}
    - message: "https://takmap.securitybits.io/{{ server }}/ :: {{ values['user'] }}:{{ values['pass'] }}"
    - api_key: {{ slack["api-key"] }}
    - require:
      - nginx service
      {%- endif %}
    {%- endif %}
  {%- endfor %}
{%- endif %}

# ##############################
# ### Services Configuration ###
# ##############################

reload nginx with new modules:
  cmd.run:
    - name: nginx -s reload
    - require:
      - nginx service

nginx service:
  service.running:
    - name: nginx
    - restart: true
    - enable: true
    - require:
      - pkg: install_nginx
    - watch:
      - pkg: nginx


