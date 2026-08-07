{
  inputs,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      evaluatedBackup = lib.nixosSystem {
        modules = [
          nixosBase
          fixture.grove.finalized.hosts.nixos.backup
        ];
        system = "x86_64-linux";
      };
      evaluatedMachine = lib.nixosSystem {
        modules = [
          nixosBase
          fixture.grove.finalized.hosts.nixos.machine
        ];
        system = "x86_64-linux";
      };
      fixture =
        let
          fixture =
            inputs.flake-parts.lib.mkFlake
              {
                inherit inputs;
                self = fixture;
              }
              {
                imports = [
                  self.flakeModules.grove
                  {
                    flake.grove = {
                      hosts = {
                        backup = {
                          firewall.enable = true;
                          hostname = "grove-backup";
                        };
                        machine = {
                          firewall.enable = true;
                          hostname = "grove-e2e";
                        };
                      };
                      overrides.hosts.nixos.machine.networking = {
                        firewall.enable = false;
                        hostName = lib.mkForce "grove-machine-override";
                      };
                      types.hosts =
                        {
                          lib,
                          ...
                        }:
                        {
                          options = {
                            firewall.enable = lib.mkOption {
                              default = true;
                              type = lib.types.bool;
                            };
                            hostname = lib.mkOption {
                              type = lib.types.str;
                            };
                          };
                        };
                    };
                  }
                  {
                    flake.grove.projectors.hosts.nixos = host: {
                      environment.etc.grove-host.text = host.config.hostname;
                      networking = {
                        firewall = {
                          allowedTCPPorts = [ 8080 ];
                          enable = lib.mkDefault host.config.firewall.enable;
                        };
                        hostName = host.config.hostname;
                      };
                    };
                  }
                  {
                    flake.grove.projectors.hosts.nixos = host: {
                      environment.etc.grove-projector-merge.text = "${host.config.hostname}-merged";
                      networking.firewall.allowedTCPPorts = [ 8443 ];
                    };
                  }
                  {
                    flake.grove.projectors.hosts.nixos = _: {
                      environment.etc.grove-projector-merge-2.text = "merged-again";
                      networking.firewall.allowedUDPPorts = [ 53 ];
                    };
                  }
                ];
              };
        in
        fixture;
      lib = inputs.nixpkgs.lib;
      nixosBase = {
        system.stateVersion = "26.11";
      };
      tests = {
        backup_firewall = {
          expected = true;
          expr = evaluatedBackup.config.networking.firewall.enable;
        };
        backup_hostname = {
          expected = "grove-backup";
          expr = evaluatedBackup.config.networking.hostName;
        };
        backup_tcp_options = {
          expected = [
            8080
            8443
          ];
          expr = evaluatedBackup.config.networking.firewall.allowedTCPPorts;
        };
        backup_udp_options = {
          expected = [ 53 ];
          expr = evaluatedBackup.config.networking.firewall.allowedUDPPorts;
        };
        machine_firewall_override = {
          expected = false;
          expr = evaluatedMachine.config.networking.firewall.enable;
        };
        machine_hostname_override = {
          expected = "grove-machine-override";
          expr = evaluatedMachine.config.networking.hostName;
        };
        machine_tcp_options = {
          expected = [
            8080
            8443
          ];
          expr = evaluatedMachine.config.networking.firewall.allowedTCPPorts;
        };
        machine_udp_options = {
          expected = [ 53 ];
          expr = evaluatedMachine.config.networking.firewall.allowedUDPPorts;
        };
        primary_projector_output = {
          expected = "grove-e2e";
          expr = evaluatedMachine.config.environment.etc.grove-host.text;
        };
        second_projector_output = {
          expected = "grove-e2e-merged";
          expr = evaluatedMachine.config.environment.etc.grove-projector-merge.text;
        };
        third_projector_output = {
          expected = "merged-again";
          expr = evaluatedMachine.config.environment.etc.grove-projector-merge-2.text;
        };
      };
    in
    {
      checks = lib.mapAttrs (
        name: test:
        pkgs.runCommand "grove-${name}" { } (
          assert lib.runTests { ${name} = test; } == [ ];
          ''
            touch "$out"
          ''
        )
      ) tests;
    };
}
