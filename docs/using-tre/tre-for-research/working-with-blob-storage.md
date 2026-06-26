# Working with Blob Storage from your workspace VM

Every workspace has an **`archive` blob container** on its shared storage account — meant for **cold / archive data**, i.e. datasets you want to keep but rarely access. Files you put in start on the Hot tier and the storage account automatically moves them to cheaper tiers (Cool → Cold → Archive) as time passes, so the longer data sits untouched, the less it costs.

This page is for the **researcher already inside a workspace VM** who wants to push data into the `archive` container and pull it back out.

## Prerequisites

- A workspace deployed from the base workspace template (version 2.1.0 or later). The `archive` container and lifecycle policy come with it — there is **no separate workspace service to deploy**.
- A workspace VM (Linux or Windows) deployed via Guacamole, with `Shared Storage Access` enabled (the default). You are connected to it through the Guacamole desktop.

You do **not** need to know any storage account keys, set up a SAS token, or `az login` interactively. The VM authenticates as itself via its system-assigned managed identity, which is granted access to the storage automatically when the VM is provisioned.

## Step 1 — Find your storage account name

In the TRE UI:

1. Open your workspace.
2. Open the workspace **Outputs** tab (or **Properties** → **Outputs**, depending on UI version).
3. Copy the value of `storage_account_name` (something like `stgworkspc270e`). This is the same storage account that hosts the workspace shared file-share.

Set it as an environment variable on the VM so you don't have to retype it:

```bash
STG=stgworkspc270e          # paste the value from Outputs
CONTAINER=archive           # always "archive" — this is the container with the lifecycle policy
```

## Step 2 — Confirm you're on the workspace network

The storage account is unreachable from the public internet — it can only be talked to from inside your workspace vnet. A quick check:

```bash
nslookup $STG.blob.core.windows.net
```

You should see an answer like:

```
Name:    stgworkspc270e.privatelink.blob.core.windows.net
Address: 10.1.4.27
```

Two things to look for:

- The CNAME points to something with `privatelink` in the name.
- The address starts with `10.` (a private IP inside your workspace).

If you see a public address (e.g. `20.x.x.x`) or the lookup fails, you're not on the workspace network — open Guacamole and connect to the workspace VM.

## Step 3 — Sign in as the VM

The VM has its own identity (a **system-assigned managed identity**) that the storage account recognises. You log in *as the VM*, not as yourself — no passwords, no codes, no browser:

```bash
az login --identity
az account show
```

The `az account show` output should include:

```json
"user": {
    "name": "systemAssignedIdentity",
    "type": "servicePrincipal"
}
```

That's it — you can now use the storage.

> Why not `az login` as yourself? In a TRE, your workspace VM is meant to be the actor that touches research data, not your laptop or your user account. Using the VM identity means everything you do is auditable as coming from *this specific VM*, and it sidesteps tenant sign-in policies that block interactive auth on workspace networks.

## Step 4 — Upload a file

```bash
echo "hello from $(hostname) at $(date)" > demo.txt

az storage blob upload \
  --account-name $STG --container-name $CONTAINER \
  --auth-mode login \
  --file ./demo.txt --name demo.txt
```

`--name` is what the file will be called inside the container. You can use a path-like name to organise into pseudo-folders:

```bash
az storage blob upload \
  --account-name $STG --container-name $CONTAINER \
  --auth-mode login \
  --file ./results.csv --name 2026-06/study1/results.csv
```

## Step 5 — List what's there

```bash
az storage blob list \
  --account-name $STG --container-name $CONTAINER \
  --auth-mode login \
  -o table
```

Just the names:

```bash
az storage blob list \
  --account-name $STG --container-name $CONTAINER \
  --auth-mode login \
  --query "[].name" -o tsv
```

Only under one prefix (the slash-separated names act like folders):

```bash
az storage blob list \
  --account-name $STG --container-name $CONTAINER \
  --auth-mode login \
  --prefix "2026-06/" -o table
```

## Step 6 — Download a file

```bash
az storage blob download \
  --account-name $STG --container-name $CONTAINER \
  --auth-mode login \
  --name demo.txt --file ./demo-out.txt

cat ./demo-out.txt
```

## Step 7 — Upload a whole folder

```bash
az storage blob upload-batch \
  --account-name $STG \
  --destination $CONTAINER \
  --auth-mode login \
  --source /path/to/local/folder
```

This preserves the directory structure under the container. It's **idempotent** — re-running it will skip files that are already there and only upload anything new or changed. Safe to retry if a session drops.

## Step 8 — Large datasets: use `azcopy`

For more than a few GB, the `az storage blob` commands work but `azcopy` is much faster (parallel, resumable):

```bash
azcopy login --identity      # signs in as the VM, same as az login --identity

azcopy copy "/path/to/local/folder" \
  "https://$STG.blob.core.windows.net/$CONTAINER/" \
  --recursive=true
```

If `azcopy` isn't installed:

```bash
wget https://aka.ms/downloadazcopy-v10-linux -O /tmp/azcopy.tgz
tar -xf /tmp/azcopy.tgz --strip-components=1 -C /tmp
sudo install /tmp/azcopy /usr/local/bin/
```

For multi-hour transfers, run it in the background so a Guacamole disconnect doesn't kill it:

```bash
nohup azcopy copy "/path/to/local/folder" \
  "https://$STG.blob.core.windows.net/$CONTAINER/" --recursive=true \
  > ~/azcopy.log 2>&1 &

tail -f ~/azcopy.log
```

## What happens to your data over time

Every blob you upload starts on the **Hot** tier (fastest access, highest cost). A lifecycle policy on the storage account automatically moves it down through cheaper tiers based on the last time the blob was modified:

| Days since last modified | Tier | Behaviour |
|---|---|---|
| 0 – 30 | **Hot** | Fastest reads/writes, highest storage cost. |
| 30 – 90 | **Cool** | Cheaper storage, very slightly higher read cost. Still milliseconds to access. |
| 90 – 180 | **Cold** | Cheaper still. Still online — milliseconds to access, but higher read cost. |
| 180+ | **Archive** | Cheapest storage. **Blob is offline** — you must rehydrate it before reading (see below). |

(Exact thresholds may be configured differently in your workspace — check the workspace service Outputs.)

If you know a file should start cheap, you can skip Hot when uploading:

```bash
az storage blob upload \
  --account-name $STG --container-name $CONTAINER \
  --auth-mode login --tier Cool \
  --file ./oldproject.tar --name oldproject.tar
```

`--tier` accepts `Hot`, `Cool`, `Cold`, or `Archive`. Be careful with `Archive` — the blob is immediately offline and you'll need to rehydrate it to read.

## Retrieving archived data

A blob that has reached the Archive tier is **offline** — `az storage blob download` will fail with a 409 error. To read it, you have to ask Azure to bring it back online (called **rehydration**):

```bash
# 1. Trigger rehydration — moves the blob back to Hot (or Cool)
az storage blob set-tier \
  --account-name $STG --container-name $CONTAINER \
  --auth-mode login \
  --name big-old-dataset.tar \
  --tier Hot --rehydrate-priority Standard

# 2. Check progress
az storage blob show \
  --account-name $STG --container-name $CONTAINER \
  --auth-mode login \
  --name big-old-dataset.tar \
  --query "{tier:properties.blobTier, status:properties.rehydrationStatus}"

# 3. Once status is "rehydrate-pending-to-hot" → "Hot" you can download as normal.
```

Rehydration with `Standard` priority can take **up to 15 hours**. `High` priority is faster (typically under 1 hour) but costs more — use it only for blobs under 10 GB.

[Azure docs: Rehydrate an archived blob](https://learn.microsoft.com/azure/storage/blobs/archive-rehydrate-overview).

## Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| `az login --identity` fails: "No identity available" | The VM doesn't have a managed identity (older bundle, or it was disabled). | Ask the workspace owner to enable system-assigned identity on the VM, then redeploy or restart. |
| `403 AuthorizationPermissionMismatch` on blob operations | The role assignment was just created and hasn't propagated yet, or `Shared Storage Access` was disabled on the VM. | Wait 2–5 minutes for role propagation. If still failing after 10 min, check that `Shared Storage Access` is enabled on the VM user resource — if it isn't, the role assignment is skipped by design. |
| `403 AuthorizationFailure` | You forgot `--auth-mode login` (it tried key auth, which is disabled), or you're running the command from outside the workspace network. | Add `--auth-mode login` to every `az storage blob …` command. Run from the workspace VM. |
| `nslookup` returns a public IP (`20.x.x.x`) | You're not on the workspace network — likely your laptop or dev container. | Open the VM via Guacamole and run the commands there. |
| `az storage blob download` returns 409 `BlobArchived` | The blob has been tiered to Archive and is offline. | Rehydrate it first — see [Retrieving archived data](#retrieving-archived-data). |
| `azcopy` says it doesn't have permission | You ran `az login --identity` but not `azcopy login --identity`. | Run `azcopy login --identity` once per session. |

## Quick reference

```bash
# variables
STG=<your-storage-account-name>
CONTAINER=archive

# one-time per session
az login --identity

# common operations
az storage blob upload   --account-name $STG --container-name $CONTAINER --auth-mode login --name <blob> --file <local>
az storage blob list     --account-name $STG --container-name $CONTAINER --auth-mode login -o table
az storage blob download --account-name $STG --container-name $CONTAINER --auth-mode login --name <blob> --file <local>
az storage blob delete   --account-name $STG --container-name $CONTAINER --auth-mode login --name <blob>

# whole folders
az storage blob upload-batch --account-name $STG --destination $CONTAINER --auth-mode login --source <folder>

# big data
azcopy login --identity
azcopy copy "<folder>" "https://$STG.blob.core.windows.net/$CONTAINER/" --recursive=true
```
