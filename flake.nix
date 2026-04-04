{
  description = "Tatara infrastructure definitions for pleme-io";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    tatara.url = "github:pleme-io/tatara";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, tatara, ... }:
  let
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems f;
  in {
    # Job specs per system — tatara's source reconciler evaluates this output.
    # Use tatara.lib.normalizeJob to convert NixOS-module-style attrsets
    # into the flat JSON format tatara expects.
    tataraJobs = forAllSystems (system: {
      # Example:
      # monitoring-agent = tatara.lib.normalizeJob "monitoring-agent" {
      #   type = "system";
      #   groups.main = {
      #     count = 1;
      #     tasks.agent = {
      #       driver = "nix";
      #       config.flake_ref = "github:pleme-io/monitoring-agent";
      #       env = {};
      #       resources = { cpu_mhz = 200; memory_mb = 128; };
      #       health_checks = [];
      #     };
      #     restart_policy = {};
      #     resources = {};
      #   };
      #   constraints = [];
      #   meta = { team = "platform"; };
      # };
    });

    tataraMeta = {
      name = "tatara-infra";
      version = "0.1.0";
      description = "pleme-io infrastructure workloads";
    };
  };
}
