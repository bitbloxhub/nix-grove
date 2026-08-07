{
  inputs,
  ...
}:
{
  flake-file.inputs = {
    github-actions-nix = {
      url = "github:synapdeck/github-actions-nix";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    junix = {
      url = "gitlab:moduon/junix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        precommix.follows = "precommix";
        systems.follows = "systems";
      };
    };
    precommix.url = "gitlab:moduon/precommix/v0.36.0";
    systems.url = "github:nix-systems/triplet";
  };

  imports = [ inputs.github-actions-nix.flakeModules.default ];

  perSystem =
    {
      lib,
      config,
      pkgs,
      inputs',
      ...
    }:
    let
      workflows = config.githubActions.workflowFiles;
    in
    {
      checks.gha =
        pkgs.runCommand "check-gha"
          {
            nativeBuildInputs = [
              pkgs.delta
              pkgs.diffutils
            ];
          }
          ''
            failed=0
            diffs="$TMPDIR/workflows.diff"
            : > "$diffs"

            ${lib.concatMapAttrsStringSep "\n" (name: drv: ''
              committed=${inputs.self}/.github/workflows/${lib.escapeShellArg name}

              if [ -e "$committed" ]; then
                if ! diff \
                  -u \
                  --label "a/.github/workflows/${name}" \
                  --label "b/.github/workflows/${name}" \
                  "$committed" \
                  ${drv} \
                  >> "$diffs"; then
                  failed=1
                fi
              else
                if ! diff \
                  -u \
                  --label "a/.github/workflows/${name}" \
                  --label "b/.github/workflows/${name}" \
                  /dev/null \
                  ${drv} \
                  >> "$diffs"; then
                  failed=1
                fi
              fi
            '') workflows}

            if [ "$failed" -ne 0 ]; then
              delta --paging=never < "$diffs"
              exit 1
            fi

            touch "$out"
          '';
      githubActions = {
        enable = true;
        workflows.ci = {
          jobs.check = {
            name = "Nix checks";
            runsOn = "ubuntu-latest";
            steps = [
              {
                name = "Checkout";
                uses = "actions/checkout@v4";
              }
              {
                name = "Free disk space for Nix";
                uses = "wimpysworld/nothing-but-nix@v10";
                with_.hatchet-protocol = "rampage";
              }
              {
                name = "Install Nix";
                uses = "cachix/install-nix-action@v31.11.0";
              }
              {
                name = "Cache Nix builds";
                uses = "Mic92/hestia@v3.0.0";
              }
              {
                name = "Load dev environment";
                run = ''
                  nix shell --inputs-from . nixpkgs#direnv -c bash -c '
                    direnv allow
                    direnv export gha >> "$GITHUB_ENV"
                  '
                '';
              }
              {
                name = "Run Nix checks";
                run = "junix check --eval-arch x86_64-linux -o report.xml";
              }
              {
                if_ = "success() || failure()";
                name = "Upload JUnit report";
                uses = "dorny/test-reporter@v3.0.0";
                with_ = {
                  fail-on-error = "true";
                  name = "Nix Build Results";
                  path = "report.xml";
                  reporter = "java-junit";
                  use-actions-summary = "true";
                };
              }
            ];
          };
          name = "CI";
          on = {
            pullRequest = { };
            push = { };
            workflowDispatch = { };
          };
          permissions.contents = "read";
        };
      };
      make-shells.default.packages = [ inputs'.junix.packages.default ];
      packages.write-gha = pkgs.writeShellScriptBin "write-gha" ''
        mkdir -p .github/workflows
        cp -r ${config.githubActions.workflowsDir}/. .github/workflows/
      '';
    };
}
