# tatara-infra

Tatara-managed infrastructure definitions for pleme-io.

## Overview

This repository exports `tataraJobs.<system>` from its Nix flake, which tatara's source reconciler watches. When commits land on main, tatara detects the revision change, re-evaluates the flake, and converges the cluster toward the declared workloads. Job specs are normalized using `tatara.lib.normalizeJob`.

## Usage

```bash
# Register with tatara
tatara source add infra github:pleme-io/tatara-infra

# Force reconciliation
tatara source sync infra

# Check source status
tatara source get infra
tatara source list
```

## Adding a Workload

Define the job spec in `flake.nix` under `tataraJobs.<system>`:

```nix
my-service = tatara.lib.normalizeJob "my-service" {
  type = "service";
  groups.main = {
    count = 2;
    tasks.server = {
      driver = "nix";
      config.flake_ref = "github:pleme-io/my-service";
      resources = { cpu_mhz = 500; memory_mb = 256; };
    };
  };
};
```

Commit and push. Tatara picks up the change on the next reconciliation tick.

## Structure

```
flake.nix       -- Exports tataraJobs.<system> and tataraMeta
shared/
  infrastructure/  -- Foundation services
  products/        -- Application workloads
```

## License

MIT
