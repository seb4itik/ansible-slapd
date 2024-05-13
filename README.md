# Ansible role slapd

Best Ansible Role ;-) for installing and configuring OpenLDAP `slapd` with multiple backends.


## Requirements

`community.general.json_query` needs `jmespath`.

```
pip3 install jmespath
```

This role must be run as `root` but it will **not** `become` by itself.


## Role Variables

| Name                    | Default              | Description                                                                           |
|-------------------------|----------------------|---------------------------------------------------------------------------------------|
| `slapd_user`            | `"openldap"`         | System user for `slapd`.                                                              |
| `slapd_group`           | `"{{ slapd_user }}"` | Group user for `slapd`.                                                               |
| `slapd_ssl`             | `false`              | Activate SSL (`ldaps:///`).                                                           |
| `slapd_ssl_group`       | `"ssl-cert"`         | Group `slapd` will be added to if `slapd_ssl` (to access keys in `/etc/ssl/private`). |
| `slapd_modules`         | `[]`                 | List of modules to add.                                                               |
| `slapd_module_path`     | `"/usr/lib/ldap"`    | Path to the directory of modules.                                                     |
| `slapd_schemas`         | `[]`                 | List of schemas to add (.ldiff or .schema format).                                    |
| `slapd_schema_path`     | `"/etc/ldap/schema"` | Path to the directory of schemas.                                                     |
| `slapd_config_olc`      | `{}`                 | Any parameter recognized by `slapd` in `cn=config`.                                   |
| `slapd_config_frontend` | `{}`                 | Any parameter recognized by `slapd` in `olcDatabase={-1}frontend,cn=config`.          |
| `slapd_config_config`   | `{}`                 | Any parameter recognized by `slapd` in `olcDatabase={0}config,cn=config`.             |
| `slapd_config_backends` | `{}`                 | Description of backends to configure.                                                 |

### slapd_ssl

If `slapd_ssl` is `true`:

- `slapd` system user (`slapd_user`) will be added to group `slapd_ssl_group`;
- `SLAPD_SERVICES` variable will be set to `"ldap:/// ldaps:/// ldapi:///"` in `/etc/defaults/slapd` file;
- `slapd` service will be restarted.

At least, these parameters must be set in `slapd_config_olc`:

- `olcTLSCertificateFile` (name of a file that should be under `/etc/ssl/certs`);
- `olcTLSCertificateKeyFile` (name of a file that should be under `/etc/ssl/private`, owner `root`, group `ssl-cert`, mode `0640`);

### slapd_config_backends

`slapd_config_backends` is the list of backends to be in `slapd` configuration (except `olcDatabase={-1}frontend,cn=config`
and `olcDatabase={0}config,cn=config` that will always exist).

Each entry in this array is a dictionary with two members:

- `db_type`: type of backend;
- `attributes`: configuration attributes and values for this backend.

Corresponding modules must be loaded for each `db_type` used:

- `ldap`: module `back_ldap`;
- `mdb`: module `back_mdb`;
- `meta`: module `back_meta`; 
- `perl`: module `back_perl`;
- `relay`: module `back_relay`;
- `sql`: module `back_sql`.

*Note: Only these backend types have been tested: `ldap`, `mdb`.*


## Dependencies

Collection `community.general`.


## Example Playbook

```
- name: Test role slapd
  hosts: ldap
  vars:
    slapd_ssl: true
    slapd_modules:
      - "back_ldap"
      - "back_mdb"
    slapd_schemas:
      - "misc"
    slapd_config_olc:
      olcLogLevel: 64
      olcTLSCertificateFile: "/etc/ssl/certs/ldap1.test.me.crt"
      olcTLSCertificateKeyFile: "/etc/ssl/private/ldap1.test.me.key"
    slapd_config_backends:
      - db_type: "ldap"
        attributes:
          olcSuffix: "dc=another,dc=me"
          olcDbURI: "ldaps:///ldap1.another.me"
      - db_type: "mdb"
        attributes:
          olcSuffix: "dc=test,dc=me"
          olcDbDirectory: "/var/lib/ldap-test-me"
          olcRootDN: "cn=admin,dc=test,dc=me"
          olcRootPW: "{{ vault.ldap.admin_dn_password }}"
          olcDbCheckpoint: "512 30"
          olcDbMaxSize: 2147483648  # 2 Go
          olcLastMod: "TRUE"
          olcSizeLimit: 1500
          olcLimits:
            - '{0}dn.base="cn=SyncRepl,ou=DIT Roles,dc=test,dc=me" size=unlimited time=unlimited'
          olcDbIndex:
            - "objectClass eq"
            - "cn,uid eq"
            - "uidNumber,gidNumber eq"
            - "member,uniqueMember,memberUid eq"
            - "sn eq,sub"
            - "givenName eq,sub"
            - "mail eq"
          olcAccess:
            - '{0}to attrs=userPassword,shadowLastChange
              by dn.base="cn=admin,ou=DIT Roles,dc=test,dc=me" write
              by dn.base="cn=pwadmin,ou=DIT Roles,dc=test,dc=me" write
              by anonymous auth
              by self write
              by * none'
            - '{1}to dn.base=""
              by * read'
            - '{2}to *
              by dn.base="cn=admin,ou=DIT Roles,dc=test,dc=me" write
              by * read'
  roles:
    - "seb4itik.slapd"
```


## Tips & Tricks

- For parameters such as `olcAccess`, `olcSyncrepl`, `olcLimits`, ... that are ordered lists,
you should prefix each item with `{N}`.
- Be careful with the case of `olcSyncrepl` parameter!


## TODO

- Manage role versions in *Ansible Galaxy*.
- Write tests (but problem between *Docker* and *systemd*).
- Validate other platforms (Ubuntu, Redhat, ...).
- Add support for backends `asyncmeta`, `dnssrv`, `null`, `passwd`, and `sock`.
- Add support for overlays.
- Add support for monitor backend.
- Remove modules not in `slapd_modules`.
- Remove schemas not in `slapd_schemas`.
- Remove configuration attributes not in `slapd_config_olc`, `slapd_config_frontend`, `slapd_config_config`, and `slapd_config_backends[]`. 


## License

MIT


## Author Information

- [seb4itik](https://github.com/seb4itik)
