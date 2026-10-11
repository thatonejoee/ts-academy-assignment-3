# DevOps Tool: CI/CD with GitHub Actions

A small Bash application with a local CI pipeline: lint, test, then build and
smoke-test a Docker image. There is no cloud deployment. Built for the DevOps
practical, Assignment 3.

Author: Joseph Fatoke

![CI](https://github.com/thatonejoee/ts-academy-assignment-3/actions/workflows/ci.yml/badge.svg)

## Project layout

| Path | Purpose |
|------|---------|
| `app/app.sh` | The application (`system-info`, `check-host`, `check-port`, `help`) |
| `scripts/lint.sh` | Checks required files exist, runs `bash -n`, runs ShellCheck if installed |
| `scripts/build.sh` | Builds the Docker image and runs smoke tests against it |
| `tests/test.sh` | Test suite for the application |
| `.github/workflows/ci.yml` | The CI pipeline |
| `Dockerfile`, `compose.yaml`, `.dockerignore` | Container setup |
| `grade.sh` | Instructor-supplied grading script |

## Setup

Requirements: Linux, Bash, and Docker (for the Docker steps).

```bash
git clone <repository-url>
cd <repository>
chmod +x grade.sh app/*.sh scripts/*.sh tests/*.sh
```

ShellCheck is optional. If it is installed (`sudo apt install shellcheck`),
`lint.sh` runs it as an extra check.

## Usage

```bash
./app/app.sh system-info
./app/app.sh check-host example.com
./app/app.sh check-port example.com 443
./app/app.sh help
```

| Command | Description |
|---------|-------------|
| `system-info` | Hostname, user, date/time, OS, kernel, architecture, uptime, CPU, memory |
| `check-host <host>` | Validates the host and resolves it |
| `check-port <host> <port>` | Validates the port (1-65535) and tests TCP connectivity |
| `help` | Shows usage |

| Exit code | Meaning |
|-----------|---------|
| 0 | Success |
| 1 | Operational failure (host does not resolve, port closed) |
| 2 | Invalid command or input |

### With Docker

```bash
docker build -t devops-tool .
docker run --rm devops-tool help
docker run --rm devops-tool system-info
docker compose run --rm app system-info
```

## Testing

```bash
./scripts/lint.sh     # required files, bash -n, ShellCheck
./tests/test.sh       # application tests
./scripts/build.sh    # build the image and run smoke tests (needs Docker)
./grade.sh            # instructor's grader
```

`tests/test.sh` contains 18 tests covering help, system-info, invalid
commands, a missing host, a valid host, an unresolvable host, a missing port,
a non-numeric port, out-of-range ports (0, 65536, 70000), a closed port and
an open port (a throwaway local server, only when `python3` is available).

## CI pipeline

The workflow in `.github/workflows/ci.yml` runs on every `push` and every
`pull_request`. It has three jobs that run in order, enforced with `needs:`:

```
validate  ->  test  ->  docker
```

| Job | Runs after | What it does |
|-----|-----------|--------------|
| `validate` | (first) | `scripts/lint.sh`: required files, `bash -n`, ShellCheck |
| `test` | `validate` succeeds | `tests/test.sh` |
| `docker` | `test` succeeds | `scripts/build.sh`: build the image, run smoke tests including an invalid-command test |

If a job fails, the jobs after it are skipped.

## CI failure demonstration

To show the pipeline catches problems, a branch was created with a deliberate
syntax error, pushed so that CI failed, and then fixed.

- Branch: `YOUR-BRANCH-NAME`
- Change that broke CI: `YOUR-DESCRIPTION` (for example, a missing `fi` in `app/app.sh`)
- Failing run: `YOUR-LINK-TO-THE-FAILED-RUN` (the `validate` job failed, so `test` and `docker` were skipped)
- Fix commit: `YOUR-COMMIT-MESSAGE`
- Passing run: `YOUR-LINK-TO-THE-PASSING-RUN` (all three jobs green)

The final workflow on `main` passes.

## Assumptions

- Docker is only needed for `scripts/build.sh`, `compose.yaml` and the
  `docker` CI job. Lint and tests run with plain Bash.
- `check-host` and `check-port` use the system resolver (`getent`).
  Resolving public hostnames needs internet access; `localhost` always works.
- TCP checks use Bash's built-in `/dev/tcp`, so `nc` is not required.
- The image runs as an unprivileged user and is built from Alpine Linux.
- No secrets are stored in the repository.
