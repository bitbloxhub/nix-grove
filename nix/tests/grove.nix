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
      # Grove finalization returns a deferred target module.
      # Evaluate it here only to inspect the target result.
      evaluatedTarget = lib.evalModules {
        modules = [
          {
            options = {
              defined = lib.mkOption {
                type = lib.types.bool;
              };
              result = lib.mkOption {
                type = lib.types.int;
              };
            };
          }
          fixture.grove.finalized.things.test.foo
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
                      things.foo.value = 123;
                      types.things =
                        {
                          lib,
                          ...
                        }:
                        {
                          options.value = lib.mkOption {
                            type = lib.types.int;
                          };
                        };
                    };
                  }
                  {
                    flake.grove.projectors.things.test = thing: {
                      defined = thing.options.value.isDefined;
                      result = thing.config.value;
                    };
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
            grove-basic-projection = {
              expected = 123;
              expr = evaluatedTarget.config.result;
            };
            grove-full-evaluation = {
              expected = true;
              expr = evaluatedTarget.config.defined;
            };
          };
    };
}
