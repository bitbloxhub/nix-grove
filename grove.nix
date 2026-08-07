{
  lib,
  self,
  ...
}:
let
  inherit (lib) mkOption types;
  finalizeClass = class: projectors: lib.mapAttrs (finalizeProjection class) projectors;
  finalizeInstance =
    class: projection: name: instance:
    let
      evaluated = lib.evalModules {
        class = "grove-${class}";
        modules = [
          self.grove.types.${class}
          instance
        ];
      };
      override = {
        file = "<grove: ${
          lib.showOption [
            "flake"
            "grove"
            "overrides"
            class
            projection
            name
          ]
        }>;";
        value = self.grove.overrides.${class}.${projection}.${name} or { };
      };
      projectorSource = {
        file = "<grove: ${
          lib.showOption [
            "flake"
            "grove"
            "projectors"
            class
            projection
          ]
        }>;";
        value = self.grove.projectors.${class}.${projection};
      };
    in
    types.deferredModule.merge
      [
        "flake"
        "grove"
        "finalized"
        class
        projection
        name
      ]
      [
        (
          projectorSource
          // {
            value = projectorSource.value evaluated;
          }
        )
        override
      ];
  finalizeProjection =
    class: projection: lib.mapAttrs (finalizeInstance class projection) (self.grove.${class} or { });
  finalizedRegistry = types.lazyAttrsOf (types.lazyAttrsOf (types.lazyAttrsOf types.deferredModule));
  instanceRegistry = types.lazyAttrsOf (types.lazyAttrsOf types.deferredModule);
  projectorType = lib.mkOptionType {
    check = builtins.isFunction;
    description = "a function from a Grove instance to a deferred module";
    merge =
      loc: defs: source:
      types.deferredModule.merge loc (
        map (
          def:
          def
          // {
            value = def.value source;
          }
        ) defs
      );
    name = "grove-projector";
  };
  reserved = [
    "types"
    "projectors"
    "overrides"
    "finalized"
  ];
  validateGrove =
    grove:
    let
      instanceClasses = builtins.attrNames (builtins.removeAttrs grove reserved);
      referencedClasses =
        instanceClasses ++ builtins.attrNames grove.projectors ++ builtins.attrNames grove.overrides;
      unknownClasses = lib.unique (
        builtins.filter (class: !(builtins.hasAttr class grove.types)) referencedClasses
      );
    in
    if unknownClasses == [ ] then
      grove
    else
      throw ''
        nix-grove: Grove classes without matching types:

          ${lib.concatStringsSep "\n  " unknownClasses}

        Define grove.types.<class> for each class.
      '';
in
{
  config.flake.grove.finalized = lib.mapAttrs finalizeClass self.grove.projectors;

  options.flake.grove = mkOption {
    apply = validateGrove;
    description = ''
      Typed instance registry and projection pipeline. Define instances
      as `flake.grove.<class>.<instance>`, describe each class with
      `flake.grove.types.<class>`, and expose projections through
      `flake.grove.projectors.<class>.<projection>`.
    '';
    type = types.submodule {
      freeformType = instanceRegistry;
      options = {
        finalized = mkOption {
          description = ''
            Generated target modules for consumers. Each
            `flake.grove.finalized.<class>.<projection>.<instance>`
            applies the projector to one evaluated instance, then
            merges its matching override from `flake.grove.overrides`.
            The result is read-only and can be imported by another
            module.
          '';
          readOnly = true;
          type = finalizedRegistry;
        };
        overrides = mkOption {
          default = { };
          description = ''
            Optional per-instance modules, indexed by
            `<class>.<projection>.<instance>`. Their definitions are
            merged into the corresponding finalized target module
            after the projector output, so they can customize or
            override projected values.
          '';
          type = finalizedRegistry;
        };
        projectors = mkOption {
          default = { };
          description = ''
            Projection functions, indexed by
            `<class>.<projection>`. A projector receives the complete
            result of `lib.evalModules` for one instance, including
            `config` and `options`, and returns a deferred module for
            the target system.
          '';
          type = types.lazyAttrsOf (types.lazyAttrsOf projectorType);
        };
        types = mkOption {
          default = { };
          description = ''
            Deferred module schemas, indexed by instance class. A
            schema declares the options available to every instance
            under `flake.grove.<class>` and is used to evaluate each
            instance before projectors run.
          '';
          type = types.lazyAttrsOf types.deferredModule;
        };
      };
    };
  };
}
