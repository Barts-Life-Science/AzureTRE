# AzureTRE#313 - Docker issues on VMs

**The issue:** <https://github.com/Barts-Life-Science/AzureTRE/issues/313> (listed on epic #146 as a migrated item). Two
problems on SDE workspace VMs: (1) the user is not automatically in the `docker` group, (2) Docker cannot pull images
through the Nexus proxy. The ticket states the fix belongs in the SDE VM customisation step, not in the images, and only
the latest image series need fixing. Acceptance checklist on the ticket: user can run `docker` commands, and Docker can
pull `hello-world`, on Ubuntu 22.04, Ubuntu 24.04, Windows 10, Windows 11 and Windows 2019 DS.

**Branch / PR:** AzureTRE fork, `patch/313-docker-user-group-and-mirror`, cut from `main` of
<https://github.com/Barts-Life-Science/AzureTRE,> pushed with the single commit `95443da8`. Prepared in the git worktree
`/home/bioku-lnx-dev/sde-image-upgrade-2026/AzureTRE-313`.  No TRE-CustomVMs change: the images already install Docker
Engine (Ubuntu) and Docker Desktop (Windows 11 / Server 2025) and leave user and proxy configuration to the SDE, which
is the correct split. AzureTRE PR #342: <https://github.com/Barts-Life-Science/AzureTRE/pull/342> (opened 2026-10-15).

**The problem:** The SDE customises each workspace VM at creation with a script rendered by Terraform: `vm_config.sh` for Linux and `vm_config.ps1` for Windows, both under `templates/workspace_services/guacamole/user_resources/` in the AzureTRE repo.

- *Linux:* `vm_config.sh` installs `docker-ce` and writes `/etc/docker/daemon.json` with `"registry-mirrors": ["${NEXUS_PROXY_URL}:8083"]`, but never adds the workspace user (`${VM_USER}`) to the `docker` group. So `docker ps` fails with "permission denied" unless the user uses `sudo`. That is problem (1) on Linux.
- *Windows:* `vm_config.ps1` writes the same mirror setting to `C:\ProgramData\docker\config\daemon.json`. That path is
  read by the Docker Engine Windows service, which the retired Windows Server 2019 image used. The Windows 11 and Server
  2025 images ship Docker Desktop with the WSL2 backend (see #148), and Docker Desktop reads the per-user
  `%USERPROFILE%\.docker\daemon.json` instead, so the mirror setting never reached it: pulls went straight to Docker
  Hub, which is blocked, and failed. That is problem (2) on Windows. The script also never adds the user to the local
  `docker-users` group, which Docker Desktop requires for anyone who is not an administrator. That is problem (1) on
  Windows.
- *Nexus side:* the `docker-hub` proxy repository (`https://registry-1.docker.io`) exposes HTTPS on port 8083 and the
  Nexus container publishes that port; the Nexus docs say `docker pull {NEXUS_URL}:8083/hello-world` works once
  anonymous access is enabled in Nexus. Nothing was changed there, but whether port 8083 is reachable from workspace
  subnets and whether anonymous access is on are things only an SDE test can confirm.

**The fix (AzureTRE repo):**
- `guacamole-azure-linuxvm/terraform/vm_config.sh`: after the Docker install, `usermod -aG docker "${VM_USER}"`. Takes effect at the user's next login.
- `guacamole-azure-windowsvm/terraform/windowsvm.tf`: pass `admin_username` into the `templatefile()` map so the script knows the user name.
- `guacamole-azure-windowsvm/terraform/vm_config.ps1`: keep the ProgramData file for Docker Engine; additionally write
  the same `daemon.json` to `C:\Users\Default\.docker\` (inherited by every new profile at first login) and to the admin
  user's profile if it already exists; create the `docker-users` local group if missing and add the admin user to it.
  ASCII only and Terraform-safe variable syntax, as the file header demands.
- Bundle versions bumped: `guacamole-azure-linuxvm` 1.2.28 to 1.2.29, `guacamole-azure-windowsvm` 1.2.19 to 1.2.20, so the TRE picks the change up when the user resource templates are re-registered.

**How to test (all inside an SDE, after registering the two updated user resource bundles):**
1. Create a new Ubuntu 24 workspace VM from the latest image. Log in as the workspace user and run `id` (expect `docker` in the group list) and `docker ps` without `sudo` (expect an empty table, not "permission denied").
2. On the same VM: `docker run hello-world`. Expect the "Hello from Docker!" text. To prove it came through Nexus: `docker info | grep -A1 "Registry Mirrors"` should show `https://<nexus host>:8083`, and the Nexus web UI should show `library/hello-world` under the `docker-hub` repository afterwards.
3. Create a new Windows 11 workspace VM from the latest image. Log in, check `C:\Users\<user>\.docker\daemon.json` exists with the mirror line, and that `net localgroup docker-users` lists the user. Start Docker Desktop, wait for "Engine running", then in PowerShell `docker run hello-world`. Expect "Hello from Docker!".
4. If step 2 or 3 fails with a connection error: from the VM, `curl -k https://<nexus host>:8083/v2/` should return a JSON response (HTTP 200 or 401), which proves port 8083 is reachable; if it is not, the Nexus VM network rules need port 8083 opened to workspace subnets. If it returns 401 for anonymous pulls, enable anonymous access in Nexus as the docs describe.
5. Tick the checklist on the ticket for Ubuntu 24 and Windows 11. Ubuntu 22, Windows 10 and Windows 2019 are retired templates and are not rebuilt this cycle.

**Test result:** NOT TESTED, 2026-10-14. Everything here can only be exercised by deploying workspace VMs in an SDE with
the updated user resource bundles, which is outside this host's tooling. What has been verified: the Linux script passes
`bash -n`; the Windows script, rendered with sample values, parses as PowerShell; `windowsvm.tf` passes `terraform fmt`;
no non-ASCII characters were introduced; the variable names used are all in the Terraform map. On the custom images
themselves, Docker Engine is present on `ubuntu-24-2026-12` (unit test `Docker OK`) and Docker Desktop is present on
`windows-11-2026-12` (unit test `Docker OK`), and after #148 the WSL package Docker Desktop needs is installed too.
