{
  description = "Tatara infrastructure definitions for pleme-io";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    tatara.url = "github:pleme-io/tatara";
  };

  outputs = { self, nixpkgs, tatara, ... }:
  let
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems f;
  in {
    tataraJobs = forAllSystems (system: {
      # Example: a monitoring agent
      # monitoring-agent = tatara.lib.normalizeJob {
      #   id = "monitoring-agent";
      #   type = "system";
      #   groups = [ ... ];
      # };
    });

    tataraMeta = {
      name = "tatara-infra";
      description = "pleme-io infrastructure workloads";
    };
  };
}
