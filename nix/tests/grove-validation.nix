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
      badInstanceClass = mkFixture [
        { flake.grove.things.foo = { }; }
      ];
      badOverrideClass = mkFixture [
        { flake.grove.overrides.things.test.foo = { }; }
      ];
      badProjectorClass = mkFixture [
        { flake.grove.projectors.things.test = _: { }; }
      ];
      consumerFinalized = mkFixture [
        {
          flake.grove.finalized.things.test.foo = { };
        }
      ];
      emptyClass = mkFixture [
        {
          flake.grove = {
            projectors.things.test = _: { };
            types.things = _: { };
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
      tests = {
        finalized_read_only = {
          expected = false;
          expr = (builtins.tryEval consumerFinalized.grove.finalized).success;
        };
        unknown_instance_class = {
          expected = false;
          expr = (builtins.tryEval badInstanceClass.grove).success;
        };
        unknown_override_class = {
          expected = false;
          expr = (builtins.tryEval badOverrideClass.grove).success;
        };
        unknown_projector_class = {
          expected = false;
          expr = (builtins.tryEval badProjectorClass.grove).success;
        };
        zero_instances = {
          expected = { };
          expr = emptyClass.grove.finalized.things.test;
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
