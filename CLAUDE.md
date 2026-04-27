# tatara-infra

> **★★★ CSE / Knowable Construction.** This repo operates under **Constructive Substrate Engineering** — canonical specification at [`pleme-io/theory/CONSTRUCTIVE-SUBSTRATE-ENGINEERING.md`](https://github.com/pleme-io/theory/blob/main/CONSTRUCTIVE-SUBSTRATE-ENGINEERING.md). The Compounding Directive (operational rules: solve once, load-bearing fixes only, idiom-first, models stay current, direction beats velocity) is in the org-level pleme-io/CLAUDE.md ★★★ section. Read both before non-trivial changes.


Canonical tatara-managed infrastructure repository for pleme-io.

## Purpose

This repo exports `tataraJobs.<system>` from its flake, which tatara's source
reconciler watches. When commits land on main, tatara detects the revision change,
re-evaluates the flake, and converges the cluster toward the declared workloads.

## Structure

```
tatara-infra/
├── flake.nix           # Exports tataraJobs.<system>
├── flake.lock
├── shared/
│   ├── infrastructure/  # Foundation services (dns, monitoring, ingress)
│   └── products/        # Application workloads
└── CLAUDE.md
```

## Adding a Workload

1. Define the job spec in `flake.nix` under `tataraJobs.<system>`:
   ```nix
   my-service = {
     id = "my-service";
     job_type = "service";
     groups = [{
       name = "main";
       count = 2;
       tasks = [{
         name = "server";
         driver = "nix";
         config.nix = {
           flake_ref = "github:pleme-io/my-service";
           args = [];
         };
         resources = { cpu_mhz = 500; memory_mb = 256; };
       }];
     }];
   };
   ```

2. Commit and push. Tatara's source reconciler will pick up the change
   on the next reconciliation tick.

## Registering with Tatara

```bash
tatara source add infra github:pleme-io/tatara-infra
```

## Operations

```bash
tatara source list              # Show all sources
tatara source get infra         # Details for this source
tatara source sync infra        # Force immediate reconciliation
tatara source suspend infra     # Pause reconciliation
tatara source resume infra      # Resume reconciliation
```
