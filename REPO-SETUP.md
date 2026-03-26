# Repo Setup Required

The container `f5d133611b7e` needs gastown-publish/gasclaw-management mounted.

## Current State
- `/workspace/gt` - empty directory
- SSH deploy key generated at `/root/.ssh/id_ed25519.pub`

## Required Action (Host)
```bash
# Option 1: Clone directly into container
lxc exec f5d133611b7e -- bash -c "cd /workspace/gt && git clone https://github.com/gastown-publish/gasclaw-management.git ."

# Option 2: Mount local path
lxc config device add f5d133611b7e gt disk source=/path/to/gasclaw-management path=/workspace/gt

# Option 3: Add remote with SSH
lxc exec f5d133611b7e -- bash -c "cd /workspace/gt && git init && git remote add origin git@github.com:gastown-publish/gasclaw-management.git"
```

## SSH Setup (if using Option 3)
1. Add deploy key to GitHub: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJilb6wP6qcUQc7BWRO7mt2+bBMeY3B5dskgo57IwgDv openclaw@gastown`
2. Configure SSH: `git config core.sshCommand "ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=no"`