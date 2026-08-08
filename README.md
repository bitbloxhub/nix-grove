# `nix-grove`

Configuration framework for `flake-parts`: define typed classes and instances, project them into NixOS, Home Manager, and other Nix module systems, and override individual results.

## Usage

Add `nix-grove` as a non-flake source, then import its module file directly:

```nix
{
  inputs.nix-grove = {
    url = "github:bitbloxhub/nix-grove";
    flake = false;
  };
}
```

In your `flake-parts` module:

```nix
{
  imports = [ (inputs.nix-grove + "/grove.nix") ];
}
```

Alternatively, omit `flake = false` and import the exported module:

```nix
{
  imports = [ inputs.nix-grove.flakeModules.default ];
  # `inputs.nix-grove.flakeModules.grove` is equivalent.
}
```


After choosing either import form above, configure Grove in your `flake-parts` module:

```nix
{

  flake.grove = {
    types.hosts =
      {
        lib,
        ...
      }:
      {
        options.hostname = lib.mkOption {
          type = lib.types.str;
        };
      };

    hosts.web.hostname = "web";

    projectors.hosts.nixos = host: {
      networking.hostName = host.config.hostname;
    };
  };
}
```

Grove evaluates each instance with its class schema, then applies projectors. Use generated modules at:

```nix
self.grove.finalized.<class>.<projection>.<instance>
```

Customize one projected instance with:

```nix
flake.grove.overrides.hosts.nixos.web = {
  networking.hostName = "web-override";
};
```

Pass the finalized deferred module to `lib.nixosSystem`:

```nix
flake.nixosConfigurations.web = lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    self.grove.finalized.hosts.nixos.web
  ];
};
```

## FAQ

### Is this dendritic?

It depends on the definition. Under mightyiam’s documented [Dendritic Pattern](https://github.com/mightyiam/dendritic/), Grove is different: Dendritic organizes a project as directly imported top-level modules, typically one feature per module. Grove instead organizes configurations around classes and instances, with projectors transforming instances into target modules and overrides customizing those projections; finalized values are deferred lower-level modules selected by target systems. Under a broader definition, calling Grove dendritic is reasonable: one top-level module system (`flake-parts`) organizes the configuration, while configuration for other module systems lives within it.
