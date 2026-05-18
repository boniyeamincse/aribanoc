# Contributing to Ariba NOC Center

Thanks for contributing to Ariba NOC Center.

This project is an open-source SOC/NOC stack built from multiple upstream tools (Prometheus, Grafana, Zabbix, ELK, Suricata, LibreNMS, NetBox, ntopng). Contributions should prioritize reliability, security, and operational clarity.

## Who Can Contribute

- SOC/NOC engineers improving monitoring and runbooks
- Sysadmins improving deployment and operations
- Developers improving automation, scripts, and configuration quality
- Security engineers improving detection, hardening, and incident workflows

## Contribution Scope

Good contribution areas:

- Docker Compose and service wiring improvements
- Monitoring rules and alert quality tuning
- Log pipeline parsing/enrichment improvements
- Setup/install automation and troubleshooting tooling
- Documentation and runbook improvements
- Security hardening and safe defaults

Out of scope for direct merge without discussion:

- Breaking changes to service ports or default runtime behavior
- Replacing major stack components
- Committing secrets, tokens, or environment-specific credentials

## Local Development Setup

### Option A: Full Auto Install

```bash
bash install.sh
```

### Option B: Existing Docker Host

```bash
cp .env.example .env
bash scripts/setup.sh
```

## Branch and Commit Workflow

1. Create a branch from `main`:

```bash
git checkout -b <type>/<short-description>
```

2. Keep commits focused and atomic.

3. Use clear commit messages, for example:

- `fix: improve logstash parsing for suricata dns events`
- `feat: add nocctl doctor check for unhealthy containers`
- `docs: update setup guide for install.sh workflow`

4. Open a pull request against `main`.

## Quality Checks (Required Before PR)

Run these checks locally:

```bash
docker compose config --quiet
bash -n scripts/*.sh
./scripts/nocctl.sh services
./scripts/nocctl.sh health
```

If you changed JSON/YAML configs, validate them as well:

```bash
python3 -m json.tool grafana/dashboards/node_exporter.json >/dev/null
```

Also verify changed services start correctly:

```bash
docker compose up -d
docker compose ps
```

## Coding and Configuration Standards

- Use ASCII by default.
- Keep scripts POSIX-safe when using `/bin/sh`.
- Avoid distro-specific commands unless guarded in installer logic.
- Keep container changes minimal and explicit.
- Preserve backward-compatible defaults where possible.
- Add short comments only where logic is not obvious.

## Security Rules

- Never commit `.env` or real secrets.
- Never hardcode credentials in code/config.
- Use placeholders in docs/examples.
- Flag potentially dangerous defaults in PR notes.
- For vulnerabilities, avoid public issue details until patched.

## Documentation Expectations

If behavior changes, update docs in the same PR:

- `README.md`
- `docs/setup.md`
- `docs/architecture.md`
- `docs/alert-runbook.md`
- `docs/documentation/index.html` (technical docs website)

## Pull Request Checklist

Before requesting review, confirm:

- [ ] No secrets or environment-specific credentials committed
- [ ] Compose config validates (`docker compose config --quiet`)
- [ ] Modified scripts pass syntax checks
- [ ] Changed services tested locally
- [ ] Docs updated for user-facing or operational changes
- [ ] PR description includes risk and rollback notes

## Reporting Issues

When opening issues, include:

- Host OS and version
- Docker and Compose versions
- Relevant service names
- Output from `./scripts/nocctl.sh doctor`
- Relevant logs (`./scripts/nocctl.sh logs <service> 200`)

## Need Help?

Start with:

```bash
./scripts/nocctl.sh doctor
```

Then share the diagnostic output in your issue or PR.