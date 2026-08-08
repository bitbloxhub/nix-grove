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
      # Evaluate finalized target module with its target-only schema.
      evaluatedTarget = lib.evalModules {
        modules = [
          {
            options.resources.value = lib.mkOption {
              type = lib.types.int;
            };
          }
          fixture.grove.finalized.things.kubenix.foo
        ];
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
                      things.foo.kubenix.resources.value = 789;
                      types.things =
                        {
                          lib,
                          ...
                        }:
                        {
                          options.kubenix = lib.mkOption {
                            default = { };
                            type = lib.types.deferredModule;
                          };
                        };
                    };
                  }
                  {
                    flake.grove.projectors.things.kubenix = thing: thing.config.kubenix;
                  }
                ];
              };
        in
        fixture;
      lib = inputs.nixpkgs.lib;
    in
    {
      checks =
        lib.mapAttrs
          (
            name: test:
            pkgs.runCommand "grove-${name}" { } (
              assert
                lib.runTests {
                  ${name} = test;
                  tests = [ name ];
                } == [ ];
              ''
                touch "$out"
              ''
            )
          )
          {
            grove-deferred-target = {
              expected = 789;
              expr = evaluatedTarget.config.resources.value;
            };
          };
    };
}
