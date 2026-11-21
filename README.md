# puppet-bolt-lab

Learn Puppet with **Bolt** (agentless, runs over SSH). Manages two servers:

| Server | Group | Manifest | Web server |
|--------|-------|----------|------------|
| `nginx-01`  | `nginx_servers`  | `manifests/nginx.pp`  | NGINX  |
| `apache-01` | `apache_servers` | `manifests/apache.pp` | Apache |

No Puppet Server and no certificates. Bolt installs `puppet-agent` on each target on the first `bolt apply`.

## Layout

```
puppet-bolt-lab/
├── .env                 # server IPs + SSH settings (edit this)
├── .env.example
├── Makefile             # shortcuts: make help
├── bolt-project.yaml
├── inventory.yaml       # reads targets from .env
└── manifests/
    ├── nginx.pp
    └── apache.pp
```

## Requirements

- Workstation: Ubuntu/Debian (or WSL) with SSH access to both servers
- Servers: Ubuntu/Debian or RHEL-family, a sudo-capable SSH user, port 80 open in the firewall/security group

## Quick start

```bash
# 1. Install Bolt (once)
make install-bolt

# 2. Edit .env: set NGINX_HOST, APACHE_HOST, SSH_USER, SSH_KEY
nano .env

# 3. Check connectivity
make check
make ping

# 4. Dry run, then apply
make noop-all
make apply-all

# 5. Verify
make test
```

## Make targets

| Target | What it does |
|--------|--------------|
| `make help` | List all targets |
| `make install-bolt` | Install Bolt (Ubuntu/Debian) |
| `make check` | Validate `.env` and Bolt install |
| `make inventory` | Show resolved targets |
| `make ping` | Run `uptime` on both servers |
| `make noop-nginx` / `make apply-nginx` | Dry run / apply nginx |
| `make noop-apache` / `make apply-apache` | Dry run / apply apache |
| `make noop-all` / `make apply-all` | Both servers |
| `make test` | `curl` both servers |
| `make drift` | Delete index.html on both servers (to test self-healing) |
| `make validate` | Puppet syntax check |
| `make clean` | Remove Bolt cache |

## Learning exercises

1. **Idempotency:** run `make apply-nginx` twice. The second run reports no changes.
2. **Drift repair:** run `make drift`, then `make apply-all`. Puppet recreates the files.
3. **`--noop`:** edit the HTML in `manifests/nginx.pp`, run `make noop-nginx`, then apply.
4. **Facts:** read how `$facts['os']['family']` picks `apache2` vs `httpd` in `apache.pp`.
5. **Ordering:** remove `require`/`notify` and observe what changes.
6. **Next:** move code into `site-modules/` as classes, add `epp()` templates, then Hiera and Bolt plans.

## Troubleshooting

- `Permission denied (publickey)`: check `SSH_USER` and `SSH_KEY` in `.env`.
- `make test` fails: open TCP 80 on the server firewall / cloud security group.
- Both services default to port 80, so keep nginx and apache on **separate** servers.
- Inspect facts: `bolt task run facts --targets all`.
