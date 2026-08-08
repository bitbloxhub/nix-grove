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
      evaluate =
        projection:
        lib.evalModules {
          modules = [
            {
              options = targetOptions;
            }
            fixture.grove.finalized.things.${projection}.foo
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
                    flake.grove.projectors.things = {
                      first = thing: {
                        result = thing.config.value;
                      };
                      second = thing: {
                        result = thing.config.value + 1;
                      };
                    };
                  }
                ];
              };
        in
        fixture;
      lib = inputs.nixpkgs.lib;
      targetOptions = {
        result = lib.mkOption {
          type = lib.types.int;
        };
      };
      tests = {
        first_projection = {
          expected = 123;
          expr = (evaluate "first").config.result;
        };
        second_projection = {
          expected = 124;
          expr = (evaluate "second").config.result;
        };
      };
    in
    {
      checks = lib.mapAttrs (
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
      ) tests;
    };
}
