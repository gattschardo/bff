{
  description = "bff";

  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      #nixpkgs.follows = nixpkgs;
    };
  };

  outputs = { self, nixpkgs, systems, treefmt-nix }:
    let
      #systems = [ "x86_64-linux" "aarch64-linux" ];
      mkPkgs = system: import nixpkgs {
        inherit system;
        config.rocmSupport = true;
      };
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
      #forAllSystems = f: nixpkgs.lib.genAttrs systems f;
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ({ pkgs, ... }: {
        projectRootFile = "treefmt.toml";
        programs.nixpkgs-fmt.enable = true;
        programs.clang-format.enable = true;
      }));
    in
    {
      packages = eachSystem (pkgs:
        let
          ROCM_GPU = "gfx1150";
          GFX_VERSION = "11.5.0";
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "bff";
            version = "0.0.0";
            src = ./.;

            buildInputs = with pkgs.rocmPackages; [
              hipcc
              clr
              rocminfo
            ];

            env.HSA_OVERRIDE_GFX_VERSION = "${GFX_VERSION}";

            buildPhase = ''
              mkdir -p build
              hipcc -O2 --amdgpu-target=${ROCM_GPU} src/main.cpp -o build/bff
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp build/bff $out/bin/
            '';
          };
        });

      devShells = eachSystem (pkgs:
        {
          default = pkgs.mkShell {
            packages = with pkgs.rocmPackages; [
              hipcc
              rocminfo
              rocm-smi
            ];

            shellHook = ''
              echo "HIP shell; ROCm GPU(s):"
              rocminfo | grep -m 3 "Name:.*gfx" || true
              export ROCM_GPU=$(rocminfo | grep -m 1 -E 'Name:.*gfx' \
                | sed -e 's/ *Name: *\(gfx[0-9a-f]*\).*/\1/')
              echo "ROCM_GPU=$ROCM_GPU"
            '';
          };
        });
      formatter = eachSystem (pkgs:
        treefmtEval.${pkgs.system}.config.build.wrapper
      );
    };
}
