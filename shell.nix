{
  system ? builtins.currentSystem,
  inputs ? (import ./.).inputs,
}: let
  pkgs = inputs.nixpkgs.legacyPackages.${system};

  devshell = import inputs.devshell {inherit system;};
  nixBin = "${pkgs.nix}/bin/nix";

  withCategory = category: attrset: attrset // {inherit category;};
  utils = withCategory "utils";
  docs = withCategory "docs";

  makeDocs = {
    name = "make-docs";
    help = "Execute the docs creating jobs and place the results in ./doc";
    command = ''
      nix build "$PRJ_ROOT#jobs.${pkgs.system}.mkApiReferenceTopLevel" \
        && cp result "$PRJ_ROOT/doc/api-reference.md" \
        && chmod 755 "$PRJ_ROOT//doc/api-reference.md"
      nix build "$PRJ_ROOT#jobs.${pkgs.system}.mkApiReferenceChannels" \
        && cp result "$PRJ_ROOT/doc/api-reference-channels.md" \
        && chmod 755 "$PRJ_ROOT//doc/api-reference-channels.md"
      nix build "$PRJ_ROOT#jobs.${pkgs.system}.mkApiReferenceHome" \
        && cp result "$PRJ_ROOT/doc/api-reference-home.md" \
        && chmod 755 "$PRJ_ROOT//doc/api-reference-home.md"
      nix build "$PRJ_ROOT#jobs.${pkgs.system}.mkApiReferenceDevshell" \
        && cp result "$PRJ_ROOT/doc/api-reference-devshell.md" \
        && chmod 755 "$PRJ_ROOT//doc/api-reference-devshell.md"
      nix build "$PRJ_ROOT#jobs.${pkgs.system}.mkApiReferenceNixos" \
        && cp result "$PRJ_ROOT/doc/api-reference-nixos.md" \
        && chmod 755 "$PRJ_ROOT//doc/api-reference-nixos.md"
    '';
  };

  test = type: name:
    withCategory "tests" {
      name = "check-${name}";
      help = "Checks ${name} ${type}";
      command = ''
        set -e
        # set -x

        tempdigga=path:$PRJ_ROOT

        trap_err() {
          local ret=$?
          echo -e \
            "\033[1m\033[31m""exit $ret: \033[0m\033[1m""command [$BASH_COMMAND] failed""\033[0m"
        }

        is () { [ "$1" -eq "0" ]; }

        trap 'trap_err' ERR

        # --------------------------------------------------------------------------------

        cd $PRJ_ROOT/${type}/${name}

        ${nixBin} flake show "$@" --override-input digga $tempdigga
        ${nixBin} flake check "$@" --override-input digga $tempdigga
      '';
    };
in
  devshell.mkShell {
    name = "vinix";

    packages = with pkgs; [
      alejandra
      fd
      nix
      nodePackages.prettier
      treefmt
    ];

    env = [
      {
        name = "NIX_CONFIG";
        value = ''          extra-experimental-features = nix-command flakes
                            extra-substituters = https://nix-community.cachix.org
                            extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs='';
      }
    ];

    commands = [
      (utils {
        name = "fmt";
        help = "Check Nix formatting";
        command = "treefmt";
      })
      (utils {
        command = "git rm --ignore-unmatch -f $PRJ_ROOT/{tests,examples,templates}/*/flake.lock";
        help = "Remove all lock files";
        name = "rm-locks";
      })
      (utils {
        name = "evalnix";
        help = "Check Nix parsing";
        command = "fd --extension nix --exec nix-instantiate --parse --quiet {} >/dev/null";
      })

      (test "templates" "vinix")
      (test "templates" "all" // {command = "check-vinix";})

      (docs {package = pkgs.mdbook;})
      (docs makeDocs)
    ];
  }
