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
      aFoo = evaluateFinalizedTarget "things" "a" "foo";
      bFoo = evaluateFinalizedTarget "things" "b" "foo";
      # Finalized values are deferred target modules.
      # This helper evaluates one with a fake target schema for assertions.
      evaluateFinalizedTarget =
        class: projection: name:
        lib.evalModules {
          modules = [
            { options = targetOptions; }
            fixture.grove.finalized.${class}.${projection}.${name}
          ];
        };
      fixture = mkFixture [
        {
          flake.grove = {
            overrides.things.test.foo.foo = 456;
            things = {
              bar.value = 234;
              foo.value = 123;
            };
            types = {
              things =
                {
                  lib,
                  ...
                }:
                {
                  options = {
                    base = lib.mkOption {
                      default = 10;
                      type = lib.types.int;
                    };
                    value = lib.mkOption {
                      type = lib.types.int;
                    };
                  };
                };
              widgets =
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
            widgets.one.value = 9;
          };
        }
        {
          flake.grove.projectors.things.test = thing: {
            base = thing.config.base;
            foo = lib.mkDefault thing.config.value;
          };
        }
        {
          flake.grove.projectors.things.test = _: {
            bar = 456;
          };
        }
        {
          flake.grove.projectors = {
            things = {
              a = thing: { foo = thing.config.value; };
              b = thing: { foo = thing.config.value + 1; };
            };
            widgets.test = thing: { foo = thing.config.value; };
          };
        }
      ];
      lib = inputs.nixpkgs.lib;
      mkFixture =
        modules:
        let
          fixture =
            inputs.flake-parts.lib.mkFlake
              {
                inherit inputs;
                self = fixture;
              }
              {
                imports = [ self.flakeModules.grove ] ++ modules;
              };
        in
        fixture;
      targetOptions = {
        bar = lib.mkOption {
          type = lib.types.int;
        };
        base = lib.mkOption {
          type = lib.types.int;
        };
        foo = lib.mkOption {
          type = lib.types.int;
        };
      };
      testBar = evaluateFinalizedTarget "things" "test" "bar";
      testFoo = evaluateFinalizedTarget "things" "test" "foo";
      tests = {
        all_instances_finalized = {
          expected = {
            bar = 234;
            foo = 456;
          };
          expr = {
            bar = testBar.config.foo;
            foo = testFoo.config.foo;
          };
        };
        all_projections_finalized = {
          expected = {
            a = 123;
            b = 124;
          };
          expr = {
            a = aFoo.config.foo;
            b = bFoo.config.foo;
          };
        };
        classes_independent = {
          expected = 9;
          expr = widget.config.foo;
        };
        missing_override = {
          expected = 234;
          expr = testBar.config.foo;
        };
        multiple_projectors_merge = {
          expected = 456;
          expr = testFoo.config.bar;
        };
        override_merges = {
          expected = 456;
          expr = testFoo.config.foo;
        };
        type_and_instance_merge = {
          expected = {
            base = 10;
            foo = 456;
          };
          expr = {
            base = testFoo.config.base;
            foo = testFoo.config.foo;
          };
        };
      };
      widget = evaluateFinalizedTarget "widgets" "test" "one";
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
