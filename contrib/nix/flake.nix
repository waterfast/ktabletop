{
  description = "Entorno de desarrollo para ktabletop (Qt6 / KF6)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          cmake
          ninja
          pkg-config
          kdePackages.wrapQtAppsHook
        ];

        buildInputs = with pkgs; [
          lua5_5
          openssl
          libgit2
          libssh2
          spdlog

          # Qt 6 & KF 6
          kdePackages.qtbase
          kdePackages.qtdeclarative
          kdePackages.kirigami
          kdePackages.kirigami-addons
          kdePackages.kcoreaddons
          kdePackages.kconfig
          kdePackages.ki18n
          kdePackages.kio
        ];

        shellHook = ''
          export LUA_INCLUDE_DIR="${pkgs.lua5_5}/include"
          export LUA_LIBRARY="${pkgs.lua5_5}/lib/liblua.so"

          # QML_IMPORT_PATH recibe directamente lo que nixpkgs genera para QML
          export QML_IMPORT_PATH="$NIXPKGS_QML_SEARCH_PATHS:$PWD/build/bin:$PWD/build/src"
          export QML2_IMPORT_PATH="$QML_IMPORT_PATH"
        '';
      };
    };
}