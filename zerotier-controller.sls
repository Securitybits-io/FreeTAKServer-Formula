{% set zerotier = pillar['zerotier'] %}

{% set name = salt['pillar.get']('zerotier:config:name') -%}
{% set iprangestart = salt['pillar.get']('zerotier:config:IpRangeStart', '192.168.192.10') -%}
{% set iprangeend = salt['pillar.get']('zerotier:config:IpRangeEnd', '192.168.192.250') -%}
{% set routetarget = salt['pillar.get']('zerotier:config:RouteTarget', '192.168.192.0') -%}
{% set cidr = salt['pillar.get']('zerotier:config:cidr', '24') -%}

install zerotier controller dependencies:
  pkg.installed:
    - pkgs:
      - jq
      - mlocate

install ZeroTier-cli:
  cmd.run:
    - name: curl -s https://install.zerotier.com | sudo bash && touch /opt/zerotier.installed
    - creates: /opt/zerotier.installed
    - require:
      - install zerotier controller dependencies

set TOKEN:
  environ.setenv:
    - name: TOKEN
    - value: __slot__:salt:cmd.run("cat /var/lib/zerotier-one/authtoken.secret")
    - require:
      - install ZeroTier-cli

set NODEID:
  environ.setenv:
    - name: NODEID
    - value: __slot__:salt:cmd.shell("zerotier-cli info | cut -d ' ' -f 3")
    - require:
      - install ZeroTier-cli


create NetworkConfig file:
  file.managed:
    - name: /opt/ZeroTAK.json
    - user: root
    - group: root
    - mode: 0600
    - contents: |
        {
          "name": "{{ name }}",
          "ipAssignmentPools": [
            {
              "ipRangeStart": "{{ iprangestart }}",
              "ipRangeEnd": "{{ iprangeend }}"
            }
          ],
          "routes": [
            {
              "target": "{{ routetarget }}/{{ cidr }}",
              "via": null
            }
          ],
          "v4AssignMode": "zt",
          "private": false
        }

create NETWORKID:
  cmd.run: 
    - name: 'curl -X POST "http://localhost:9993/controller/network/${NODEID}______" -H "X-ZT1-AUTH: ${TOKEN}" -d @ZeroTAK.json && touch /opt/zerotier.netid'
    - cwd: /opt
    - creates: /opt/zerotier.netid
    - require:
      - set TOKEN
      - set NODEID
      - create NetworkConfig file

set NWID:
  environ.setenv:
    - name: NWID
    - value: __slot__:salt:cmd.shell('cat /var/lib/zerotier-one/controller.d/network/*.json | jq -r .nwid')
    - require:
      - create NETWORKID

echo NWID:
  cmd.run:
    - name: echo -n $NWID > /opt/zerotier.netid

store NWID in SaltMine:
  module.run:
    - name: mine.update

{% set slack = pillar['slack'] %}
{% if slack["post"] == True %}
post NetworkID:
  slack.post_message:
    - channel: {{ slack["channel-name"] }}
    - from_name: {{ grains['host'] }}
    - message: __slot__:salt:cmd.shell('cat /opt/zerotier.netid')
    - api_key: {{ slack["api-key"] }}
    - require:
      - set NWID
{% endif %}


# call API to assign IPs to IDs
{% for server, value in salt['pillar.get']('zerotier:identities').items() %}
{% set identity = value['secret'].split(":")[0] %}

create network config file for {{ server }}:
  file.managed:
    - name: /opt/{{ server }}.json
    - mode: 0600
    - user: root
    - group: root
    - contents: |
        {
          "address":"{{ identity }}",
          "ipAssignments":["{{ value['ipAssignments'] }}/{{ cidr }}"]
        }

assign ip for {{ server }} with {{ identity }}:
  cmd.run: 
    - name: 'curl -X POST "http://localhost:9993/controller/network/${NWID}/member/{{ identity }}" -H "X-ZT1-AUTH: ${TOKEN}" -d @/opt/{{ server }}.json'
    - cwd: /opt
    - require:
      - set TOKEN
      - set NODEID
      - create network config file for {{ server }}
{% endfor %}

# Distribute the ID Files to clients
# https://github.com/zerotier/ZeroTierOne/tree/master/controller