{% set zerotier = pillar['zerotier'] %}
{% set client = grains['id'] %}

install zerotier client dependencies:
  pkg.installed:
    - pkgs:
      - jq
      - mlocate

install ZeroTier-cli:
  cmd.run:
    - name: curl -s https://install.zerotier.com | sudo bash && touch /opt/zerotier.installed
    - creates: /opt/zerotier.installed
    - require:
      - install zerotier client dependencies

# get the secret and public identity
#-rw-r--r--  1 zerotier-one zerotier-one  141 Feb 23 20:23 identity.public
#-rw-------  1 zerotier-one zerotier-one  271 Feb 23 20:23 identity.secret
{% for server, value in salt['pillar.get']('zerotier:identities').items() -%}
{% if server == client -%}

{% set public = value['secret'].split(':')[0:3] | join(':') -%}
{% set private = value['secret'] -%}
stop zerotier-one:
  service.dead:
    - name: zerotier-one

create public file:
  file.managed:
    - name: /var/lib/zerotier-one/identity.public
    - mode: 0644
    - user: zerotier-one
    - group: zerotier-one
    - contents: {{ public }}
    - require:
      - install ZeroTier-cli
      - stop zerotier-one

create secret file:
  file.managed:
    - name: /var/lib/zerotier-one/identity.secret
    - mode: 0600
    - user: zerotier-one
    - group: zerotier-one
    - contents: {{ private }}
    - require:
      - install ZeroTier-cli
      - stop zerotier-one

start zerotier-one:
  service.running:
    - name: zerotier-one

{% endif -%}
{% endfor -%}

{% set id = zerotier['controller'] -%}
{% set NWIDs = salt['mine.get'](id, 'zerotier-network-key') -%} 
{% set nwid = NWIDs.values() | first -%}
joining controller {{ id }}:
  cmd.run:
    - name: /var/lib/zerotier-one/zerotier-cli join {{ nwid }} && touch /opt/zerotier-{{ nwid }}.joined
    - creates: /opt/zerotier-{{ nwid }}.joined
    - require:
      - install ZeroTier-cli
