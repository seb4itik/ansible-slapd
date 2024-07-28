# Ansible role slapd

The best Ansible Role ;-) for installing and configuring OpenLDAP `slapd` with multiple backends.

## Features

- Idempotent (but see [Notes](#notes)).
- Multiple backends.
- Modules management.
- Schemas management.
- Overlay management.
- SSL activation.
- Monitor backend activation.
- Apparmor aware (for Ubuntu).
- Debian and Ubuntu friendly (anyone for Redhat likes and other platforms?).
- A developer/maintainer willing to receive feedback and bug reports.


## Requirements

`community.general.json_query` needs `jmespath`:

```
pip3 install jmespath
```

This role must be run as `root` (for `EXTERNAL` authentification mechanism)
but will **not** `become` by itself.


## Role Variables

| Name                    | Default              | Description                                                                           |
|-------------------------|----------------------|---------------------------------------------------------------------------------------|
| `slapd_user`            | `"openldap"`         | System user for `slapd`.                                                              |
| `slapd_group`           | `"{{ slapd_user }}"` | Group user for `slapd`.                                                               |
| `slapd_ssl`             | `false`              | Activate SSL (`ldaps:///`).                                                           |
| `slapd_ssl_group`       | `"ssl-cert"`         | Group `slapd` will be added to if `slapd_ssl` (to access keys in `/etc/ssl/private`). |
| `slapd_monitor`         | `false`              | Activate monitor backend (`cn=Monitor`).                                              |
| `slapd_monitor_admin`   | required if `slapd_monitor` | DN that will have read access to `cn=Monitor`.                                 |
| `slapd_modules`         | `[]`                 | List of modules to add.                                                               |
| `slapd_module_path`     | `"/usr/lib/ldap"`    | Path to the directory of modules.                                                     |
| `slapd_schemas`         | `[]`                 | List of schemas to add (`.ldiff` or `.schema` format).                                |
| `slapd_schema_path`     | `"/etc/ldap/schema"` | Path to the directory of schemas.                                                     |
| `slapd_apparmor_file`   | `"/etc/apparmor.d/usr.sbin.slapd"`| Path to `slapd` apparmor profile file.                                   |
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

Each entry in this array is a dictionary with two or three members:

- `db_type`: type of backend;
- `overlays`: overlays for this backend (optional), must have `name` and `attributes` attributes;
- `attributes`: configuration attributes and values for this backend.

Corresponding modules must be loaded for each `overlay` used (supported overlays are: `accesslog`, `auditlog`,
`autogroup`, `collect`, `constraint`, `dds`, `dyngroup`, `dynlist`, `homedir`, `lastbind`, `memberof`, `pcache`,
`ppolicy`, `refint`, `remoteauth`, `retcode`, `rwm`, `sssvlv`, `syncprov`, `translucent`, `unique`, `valsort`).

Corresponding modules must be loaded for each `db_type` used:

- `asyncmeta`: module `back_asyncmeta`;
- `dnssrv`: module `back_dnssrv`;
- `ldap`: module `back_ldap`;
- `mdb`: module `back_mdb`;
- `meta`: module `back_meta`;
- `null`: module `back_null`;
- `passwd`: module `back_passwd`;
- `perl`: module `back_perl`;
- `relay`: module `back_relay`;
- `sock`: module `back_sock`;
- `sql`: module `back_sql`.

*Note: Only these backend types have been tested: `ldap`, `mdb`.*


## Dependencies

Collection `community.general`.


## Notes

This role will *not* create the root DN entry for backends.

For adding the schema `my-schema`, the file `my-schema.ldif` or `my-schema.schema` must exist
in `/etc/ldap/schema` (or whatever `{{slapd_schema_path}}` is).

Due to OpenLDAP `slapd` limitations, it's not possible to dynamically remove modules and
schemas. So, even if you remove a module from `slapd_modules` or a schema from `slapd_schemas`,
this role will not try to remove them from the `slapd` configuration.

Removing configuration attributes from `slapd_config_olc`, `slapd_config_frontend`,
`slapd_config_config`, `slapd_config_backends[*].attributes`, and
`slapd_config_backends[*].overlays.attributes` will not remove them from `slapd`configuration.
See [this bug report](https://github.com/ansible-collections/community.general/issues/8354)
for `community.general.ldap_attrs`

The workaround for removing an attribute is to use `[]`. Exemple:

```
    slapd_config_olc:
      olcLogLevel: []
```


## Example Playbooks

Minimal playbook:

```
- name: Minimal playbook for role seb4itik.slapd
  hosts: ldap
  vars:
    slapd_modules:
      - "back_mdb"
    slapd_config_backends:
      - db_type: "mdb"
        attributes:
          olcSuffix: "dc=test,dc=me"
          olcDbDirectory: "/var/lib/ldap-test-me"
          olcRootDN: "cn=admin,dc=test,dc=me"
          olcRootPW: "{{ vault.ldap.admin_dn_password }}"
  roles:
    - "seb4itik.slapd"
```

More complete example:

```
- name: Example playbook for role seb4itik.slapd
  hosts: ldap
  vars:
    slapd_ssl: true
    slapd_monitor: true
    slapd_monitor_admin: "gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth"
    slapd_modules:
      - "back_ldap"
      - "back_mdb"
      - "constraint"
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
        overlays:
          - name: "constraint"
            attributes:
              olcConstraintAttribute:
                - "mail regex ^[[:alnum:]]+@mydomain.com$"
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

- Write tests (but problem between *Docker* and *systemd*).
- Other platforms (Redhat, ...).
- Optimisation: set_fact (all modules, all schemas, all suffixes...)
- Idempotency in attributes (for replacing "state: exact")

## License

MIT


## Author Information

- [seb4itik](https://github.com/seb4itik)
