# Contributing

Thanks for considering contributing to k8s-platform.

## Getting started

1. Fork the repo and clone it locally
2. Install prerequisites (see README)
3. Run `make bootstrap` to verify everything works
4. Create a feature branch: `git checkout -b feature/your-thing`

## Development workflow

```bash
make bootstrap      # set up the platform
make status         # check everything is running
make verify         # run smoke tests
make lint           # check code quality
make test           # run unit tests
```

## Making changes

- **Infrastructure** (terraform/, kubernetes/, helm/): test with `make bootstrap` on a clean cluster
- **Application** (app/): run `make test` and `make build`
- **CI/CD** (.github/workflows/): test with [act](https://github.com/nektos/act) locally if possible
- **Monitoring** (monitoring/, helm/monitoring/): verify dashboards load in Grafana after deploy

## Commit messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add backup script for etcd
fix: correct network policy for DNS egress
docs: update deployment guide
chore: bump prometheus-stack chart version
```

## Pull requests

1. Keep PRs focused — one feature or fix per PR
2. Update docs if you change behavior
3. Ensure `make lint` and `make test` pass
4. Add a description of what you changed and why
5. Screenshots for UI changes (Grafana dashboards, frontend)

## Code style

- YAML: 2-space indent, no trailing whitespace
- Python: follow flake8 with max-line-length 120
- Terraform: `terraform fmt` before committing
- Shell scripts: use `shellcheck` if available

## Architecture decisions

If your change affects architecture (new tools, different patterns), open an issue first to discuss. Reference [docs/architecture.md](docs/architecture.md) for current design.

## Security

- Never commit secrets, tokens, or credentials
- Use Vault for application secrets
- Use GitHub Secrets for CI/CD credentials
- Report security issues privately (do not open a public issue)
