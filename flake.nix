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
    linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems f;
    forLinuxSystems = f: nixpkgs.lib.genAttrs linuxSystems f;
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

    # OCI images for the ro platform — containerd 2.x compatible.
    # Build: nix build .#packages.x86_64-linux.attic-server-image
    # Push:  skopeo copy docker-archive:result docker://ghcr.io/pleme-io/attic-server:latest
    packages = forLinuxSystems (system: let
      pkgs = import nixpkgs { inherit system; };
      archTag = {
        "x86_64-linux" = "amd64";
        "aarch64-linux" = "arm64";
      };

      # Build tatara-operator from the tatara workspace source.
      tatara-operator-bin = pkgs.rustPlatform.buildRustPackage {
        pname = "tatara-operator";
        version = "0.1.0";
        src = tatara;
        cargoLock = {
          lockFile = "${tatara}/Cargo.lock";
          outputHashes = {
            "kasou-0.1.0" = "sha256-7n0xnbmmunzMsfl+m9/P8mmHbC4tKz1QpK3yLP+sZDA=";
            "shikumi-0.1.0" = "sha256-6oIj/AIuFKV5MlAkZcrk2Qy5dtQ0zV8qk9I+5uqZkPA=";
          };
        };
        cargoBuildFlags = [ "--package" "tatara-operator" ];
        nativeBuildInputs = with pkgs; [ pkg-config ];
        buildInputs = with pkgs; [ openssl ];
      };
    in {
      attic-server-image = pkgs.dockerTools.buildLayeredImage {
        name = "ghcr.io/pleme-io/attic-server";
        tag = "${archTag.${system}}-latest";
        contents = with pkgs; [
          attic-server
          cacert
          coreutils
        ];
        # Create real /etc/passwd and /etc/group files — containerd 2.x
        # rejects Nix symlinks that point into /nix/store/ as "path escapes
        # from parent". Real files in the image layer avoid this.
        extraCommands = ''
          mkdir -p etc tmp var/log
          echo "root:x:0:0:root:/root:/bin/sh" > etc/passwd
          echo "nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin" >> etc/passwd
          echo "root:x:0:" > etc/group
          echo "nogroup:x:65534:" >> etc/group
          chmod 1777 tmp
        '';
        config = {
          Entrypoint = [ "${pkgs.attic-server}/bin/atticd" ];
          ExposedPorts = { "8080/tcp" = {}; };
          Env = [
            "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            "RUST_LOG=info"
          ];
        };
      };

      # Nix builder image — privileged container with nix-daemon, SSH, attic-client.
      # Used by pleme-nix-builder chart for executing builds.
      nix-builder-image = pkgs.dockerTools.buildLayeredImage {
        name = "ghcr.io/pleme-io/nix-builder";
        tag = "${archTag.${system}}-latest";
        contents = with pkgs; [
          nix
          openssh
          attic-client
          bashInteractive
          coreutils
          cacert
          git
          gnutar
          gzip
          xz
        ];
        extraCommands = ''
          mkdir -p etc tmp root/.ssh var/log nix/var/nix
          echo "root:x:0:0:root:/root:/bin/bash" > etc/passwd
          echo "nixbld:x:30000:30000:Nix build user:/var/empty:/usr/sbin/nologin" >> etc/passwd
          echo "sshd:x:74:74:sshd:/var/empty:/usr/sbin/nologin" >> etc/passwd
          echo "root:x:0:" > etc/group
          echo "nixbld:x:30000:" >> etc/group
          chmod 1777 tmp
          chmod 700 root/.ssh
        '';
        config = let
          path = pkgs.lib.makeBinPath [ pkgs.nix pkgs.openssh pkgs.attic-client pkgs.bashInteractive pkgs.coreutils pkgs.git pkgs.gnutar pkgs.gzip pkgs.xz ];
        in {
          Entrypoint = [ "${pkgs.bashInteractive}/bin/bash" "-c" "exec sshd -D -e" ];
          ExposedPorts = { "22/tcp" = {}; };
          Env = [
            "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            "PATH=${path}"
          ];
        };
      };

      tatara-operator-image = pkgs.dockerTools.buildLayeredImage {
        name = "ghcr.io/pleme-io/tatara-operator";
        tag = "${archTag.${system}}-latest";
        contents = with pkgs; [
          tatara-operator-bin
          cacert
        ];
        extraCommands = ''
          mkdir -p etc tmp
          echo "root:x:0:0:root:/root:/bin/sh" > etc/passwd
          echo "nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin" >> etc/passwd
          echo "root:x:0:" > etc/group
          echo "nogroup:x:65534:" >> etc/group
          chmod 1777 tmp
        '';
        config = {
          Entrypoint = [ "${tatara-operator-bin}/bin/tatara-operator" ];
          ExposedPorts = { "8080/tcp" = {}; };
          Env = [
            "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            "RUST_LOG=info"
          ];
          User = "65534:65534";
        };
      };
    });
  };
}
