{
  description = "DullGym - Android workout tracking app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        androidComposition = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "36" "35" "34" "33" ];
          buildToolsVersions = [ "36.0.0" "35.0.0" "34.0.0" "33.0.1" ];
          includeEmulator = true;
          emulatorVersion = "35.1.19";
          includeSystemImages = true;
          systemImageTypes = [ "google_apis_playstore" ];
          abiVersions = [ "x86_64" ];
          includeNDK = true;
          ndkVersions = [ "27.0.12077973" "26.3.11579264" ];
          cmakeVersions = [ "3.22.1" ];
          cmdLineToolsVersion = "13.0";
        };

        androidSdk = androidComposition.androidsdk;
        sdkPath = "${androidSdk}/libexec/android-sdk";
        cmdlineTools = "${sdkPath}/cmdline-tools/13.0/bin";

        avdName = "dullgym";
        systemImage = "system-images;android-34;google_apis_playstore;x86_64";

        locScript = pkgs.writeShellScriptBin "loc" ''
          echo "Lines of Code (lib/):"
          echo "─────────────────────────────────"
          total=0
          for file in $(find lib -name "*.dart" 2>/dev/null | sort); do
            count=$(wc -l < "$file")
            printf "%-45s %5d\n" "$file" "$count"
            total=$((total + count))
          done
          echo "─────────────────────────────────"
          printf "%-45s %5d\n" "Total" "$total"
        '';

        emuSetupScript = pkgs.writeShellScriptBin "emu-setup" ''
          export ANDROID_HOME="${sdkPath}"
          export ANDROID_SDK_ROOT="${sdkPath}"
          AVDMANAGER="${cmdlineTools}/avdmanager"

          if $AVDMANAGER list avd 2>/dev/null | grep -q "Name: ${avdName}"; then
            echo "AVD '${avdName}' already exists"
          else
            echo "Creating AVD '${avdName}'..."
            echo "no" | $AVDMANAGER create avd -n ${avdName} -k "${systemImage}" -d pixel_6 --force
            if [ $? -eq 0 ]; then
              echo "AVD created successfully"
            else
              echo "ERROR: Failed to create AVD" >&2
              exit 1
            fi
          fi
        '';

        emuScript = pkgs.writeShellScriptBin "emu" ''
          export ANDROID_HOME="${sdkPath}"
          export ANDROID_SDK_ROOT="${sdkPath}"
          AVDMANAGER="${cmdlineTools}/avdmanager"

          if ! $AVDMANAGER list avd 2>/dev/null | grep -q "Name: ${avdName}"; then
            echo "AVD not found, running setup..."
            emu-setup || exit 1
          fi
          echo "Starting emulator..."
          ${sdkPath}/emulator/emulator -avd ${avdName} "$@"
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Flutter
            flutter
            dart

            # Android
            androidSdk
            jdk17

            # Build tools
            cmake
            ninja
            pkg-config

            # For Linux desktop builds
            gtk3
            glib
            pcre2
            util-linux
            libselinux
            libsepol
            libthai
            libdatrie
            xorg.libXdmcp
            xorg.libXtst
            libxkbcommon
            libepoxy
            at-spi2-core
            dbus

            # Utilities
            git
            unzip
            which
            locScript
            emuSetupScript
            emuScript
          ];

          ANDROID_HOME = sdkPath;
          ANDROID_SDK_ROOT = sdkPath;
          JAVA_HOME = "${pkgs.jdk17}";
          CHROME_EXECUTABLE = "${pkgs.chromium}/bin/chromium";

          # Libraries for nix-ld (for dynamically linked binaries like aapt2)
          NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
            zlib
            libGL
            xorg.libX11
            xorg.libXext
            xorg.libXrender
            fontconfig
            freetype
            stdenv.cc.cc.lib
          ]);

          shellHook = ''
            export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$PATH"

            echo "DullGym dev environment loaded"
            echo "Flutter: $(flutter --version 2>/dev/null | head -n 1)"
            echo ""
            echo "Commands:"
            echo "  flutter pub get     - Install dependencies"
            echo "  flutter run         - Run on connected device/emulator"
            echo "  flutter build apk   - Build release APK"
            echo "  loc                 - Count lines of code"
            echo "  emu-setup           - Create Android emulator (one-time)"
            echo "  emu                 - Launch Android emulator"
          '';
        };
      }
    );
}
