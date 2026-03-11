{
  description = "bff";

  inputs = {
    systems.url = "github:nix-systems/default";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = { self, nixpkgs, systems, treefmt-nix }:
    let
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
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
              make all
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
              clr
              rocm-smi
            ] ++ [ pkgs.gnumake ];

            # TODO: calculate based on ROCM_GPU
            HSA_OVERRIDE_GFX_VERSION = "11.5.0";

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
        treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper
      );
      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
      });
    };
}
