Role slapd
==========

This install and configure OpenLDAP `slapd` with an MDB database.


Requirements
------------

`community.general.json_query` needs `jmespath`.

```
pip3 install jmespath
```


Role Variables
--------------

| Name                       | Default/Required       | Description                                                                  |
|----------------------------|:----------------------:|------------------------------------------------------------------------------|
| `slapd_rootdn`             | :heavy_check_mark:     | Root DN for the MDB backend.                                                 |
| `slapd_admin_dn`           | :heavy_check_mark:     | Administrator DN for the MDB backend.                                        |
| `slapd_admin_pw`           | :heavy_check_mark:     | Password of administrator DN for the MDB backend.                            |
| `slapd_modules`            | `[]`                   | List of modules to add.                                                      |
| `slapd_module_path`        | `"/usr/lib/ldap"`      | Path to the directory of modules.                                            |
| `slapd_schemas`            | `[]`                   | List of schemas to add (.ldiff or .schema format).                           |
| `slapd_schema_path`        | `"/etc/ldap/schema"`   | Path to the directory of schemas.                                            |
| `slapd_services`           | `"ldap:/// ldapi:///"` | Sockets to listen to (setup in `/etc/default/slapd` file).                   |
| `slapd_user`               | `"openldap"`           | System user for `slapd`.                                                     |
| `slapd_group`              | `"{{ slapd_user }}"`   | Group user for `slapd`.                                                      |
| `slapd_db_directory`       | `"/var/lib/ldap"`      | Path to the directory for storing MDB database files.                        |
| `slapd_db_checkpoint`      | `"512 30"`             | Chechpoint parameters storing MDB database.                                  |
| `slapd_config_olc`         | `{}`                   | Any parameter recognized by `slapd` in `cn=config`.                          |
| `slapd_config_db_frontend` | `{}`                   | Any parameter recognized by `slapd` in `olcDatabase={-1}frontend,cn=config`. |
| `slapd_config_db_config`   | `{}`                   | Any parameter recognized by `slapd` in `olcDatabase={0}config,cn=config`.    |
| `slapd_config_db_mdb`      | `{}`                   | Any parameter recognized by `slapd` in `olcDatabase={1}mdb,cn=config`.       |


Dependencies
------------

Collection `community.general`.


Example Playbook
----------------

```
- name: Copy schema files
  ansible.builtin.copy:
    src: "files/schema/"
    dest: "/etc/ldap/schema/"
    mode: "0644"
    owner: "root"
    group: "root"

- name: Install slapd
  vars:
    slapd_rootdn: "dc=test,dc=me"
    slapd_admin_dn: "cn=admin,dc=test,dc=me"
    slapd_admin_pw: "{{ vault.ldap.admin_dn_password }}"
    slapd_modules: ["syncprov"]
    slapd_schemas:
      - "sendmail"
      - "samba"
    slapd_config_olc:
      olcServerID:
        - "1 ldaps://ldap1.test.me/"
        - "2 ldaps://ldap2.test.me/"
    slapd_config_db_mdb:
      olcSizeLimit: 1500
      olcLimits:
        - '{0}dn.regex="cn=SyncRepl,ou=DIT Roles,cn=admin,dc=test,dc=me" size=unlimited time=unlimited'
      olcDbIndex:
        - "mail eq"
        - "mailLocalAddress eq"
        - "sendmailMTAHost eq"
        - "sendmailMTAAliasGrouping eq"
        - "sendmailMTACluster eq"
        - "sendmailMTAKey eq"
        - "sambaPrimaryGroupSID eq"
        - "sambaSID eq"
        - "sambaGroupType eq"
        - "sambaSIDList eq"
      olcAccess:
        - '{0}to attrs=userPassword,shadowLastChange,sambaNTPassword,sambaLMPassword
           by dn.base="cn=admin,ou=DIT Roles,dc=test,dc=me" write
           by dn.base="cn=pwadmin,ou=DIT Roles,dc=test,dc=me" write
           by dn.base="cn=sambaadmin,ou=DIT Roles,dc=test,dc=me" write
           by dn.base="cn=SyncRepl,ou=DIT Roles,dc=test,dc=me" read
           by anonymous auth
           by self write
           by * none'
        - '{1}to dn.base=""
           by * read'
        - '{2}to *
           by dn.base="cn=admin,ou=DIT Roles,dc=test,dc=me" write
           by dn.base="cn=sambaadmin,ou=DIT Roles,dc=test,dc=me" write
           by dn.base="cn=SyncRepl,ou=DIT Roles,dc=test,dc=me" read
           by * read'
      olcSyncrepl:
        - '{0}rid=1
           provider=ldaps://ldap1.test.me
           binddn="cn=SyncRepl,ou=DIT Roles,dc=test,dc=me"
           bindmethod=simple
           credentials={{ vault.ldap.syncrepl_password }}
           searchbase="dc=test,dc=me"
           type=refreshAndPersist
           retry="5 5 300 +"
           timeout=1
           starttls=yes'
        - '{1}rid=2
           provider=ldaps://ldap2.test.me
           binddn="cn=SyncRepl,ou=DIT Roles,dc=test,dc=me"
           bindmethod=simple
           credentials={{ vault.ldap.syncrepl_password }}
           searchbase="dc=test,dc=me"
           type=refreshAndPersist
           retry="5 5 300 +"
           timeout=1
           starttls=yes'
      olcMultiProvider: "TRUE"
  ansible.builtin.import_role:
    name: "slapd"

- name: Copy SSL certificate, key and CA
  loop:
    - name: "CA-bundle.crt"
      mode: "0644"
    - name: "_test.me.crt"
      mode: "0644"
    - name: "_test.me.key"
      mode: "0640"
  ansible.builtin.copy:
    src: "files/{{ item.name }}"
    dest: "/etc/ldap/{{ item.name }}"
    owner: "root"
    group: "openldap"
    mode: "{{ item.mode }}"

- name: Activate slapd SSL
  vars:
    slapd_services: "ldap:/// ldaps:/// ldapi:///"
    slapd_config_olc:
      olcTLSCACertificateFile: "/etc/ldap/CA-bundle.crt"
      olcTLSCertificateFile: "/etc/ldap/_test.me.crt"
      olcTLSCertificateKeyFile: "/etc/ldap/_test.me.key"
  ansible.builtin.import_role:
    name: "slapd"
```


Tips & Tricks
-------------

FIXME
- `olcAccess`, `olcSyncrepl`, `olcLimits` => {0}
- case of `olcSyncrepl`
- activation SSL after installation for `openldap` group


License
-------

MIT


Author Information
------------------

- [seb4itik](https://github.com/seb4itik)
