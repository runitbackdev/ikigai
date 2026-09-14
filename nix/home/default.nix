# The user half of Ikigai as a Home Manager module: every app config the installer used to
# seed, the theme's per-app files, the directories, the shell. Nix owns these files now:
# change them in the flake and rebuild. The few files apps write back themselves (the
# rail's shell.json, btop's config, Vicinae's settings) are seeded once and then yours.
{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}:
let
  cfg = config.ikigai;
  themeName = if osConfig != null then osConfig.ikigai.theme else cfg.theme;
  theme = pkgs.ikigai-theme.override { name = themeName; };
  t = "${theme}/share/ikigai/themes/${themeName}";
  # The same files from the tree, for what has to be read at evaluation.
  themeSrc = ../../themes + "/${themeName}";
  seeds = ../../config;
  # Copy a file into place once, only where nothing exists: for the files an app writes.
  seedOnce =
    target: source:
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${target}" ]; then
        run mkdir -p "$(dirname "${target}")"
        run install -m644 "${source}" "${target}"
      fi
    '';
in
{
  options.ikigai = {
    enable = lib.mkEnableOption "the Ikigai home configuration";
    theme = lib.mkOption {
      type = lib.types.str;
      default = "ikigai";
      description = "The theme, when this module runs outside the NixOS module.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.stateVersion = lib.mkDefault "25.11";

    # ---- the dev stack, per user ---------------------------------------------------
    home.packages = with pkgs; [
      claude-code
      gh
      just
      neovim
      zellij
      yazi
      lazygit
      btop
      eza
      dust
      tealdeer
      jq
      fastfetch
      python3
      zip
      unzip
    ];
    home.sessionPath = [ "$HOME/.local/bin" ];
    home.sessionVariables = {
      EDITOR = "zed --wait";
      VISUAL = "zed --wait";
    };

    # ---- shell ---------------------------------------------------------------------
    programs.zsh = {
      enable = true;
      dotDir = config.home.homeDirectory;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      history = {
        size = 100000;
        save = 100000;
        ignoreAllDups = true;
        ignoreSpace = true;
        share = true;
      };
      shellAliases = {
        ls = "eza --icons --group-directories-first";
        ll = "eza -l --icons --group-directories-first --git";
        la = "eza -la --icons --group-directories-first --git";
        tree = "eza --tree --icons";
        cat = "bat --paging=never";
        du = "dust";
        grep = "rg";
        lg = "lazygit";
        ld = "lazydocker";
        c = "clear";
        zj = "zellij attach --create main";
      };
      initContent = ''
        setopt AUTO_CD INTERACTIVE_COMMENTS
        zstyle ':completion:*' menu select
        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"

        bindkey -e
        bindkey '^[[1;5C' forward-word
        bindkey '^[[1;5D' backward-word
        bindkey '^[[3~' delete-char

        git_current_branch() {
          local ref
          ref=$(git symbolic-ref --quiet HEAD 2>/dev/null) || ref=$(git rev-parse --short HEAD 2>/dev/null) || return
          echo "''${ref#refs/heads/}"
        }
        source "$HOME/.config/zsh/git-aliases.zsh"

        [ -f "$HOME/.config/secrets.zsh" ] && source "$HOME/.config/secrets.zsh"
        [ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
      '';
    };
    xdg.configFile."zsh/git-aliases.zsh".source = "${seeds}/zsh/git-aliases.zsh";
    programs.starship = {
      enable = true;
      enableZshIntegration = true;
    };
    xdg.configFile."starship.toml".source = "${seeds}/starship/starship.toml";
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --exclude .git";
      fileWidget.command = "fd --type f --hidden --exclude .git";
      defaultOptions = [
        "--color=16"
        "--highlight-line"
        "--info=inline-right"
        "--ansi"
        "--layout=reverse"
        "--border=none"
      ];
    };
    programs.mise = {
      enable = true;
      enableZshIntegration = true;
    };
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
      shellWrapperName = "y";
    };
    xdg.configFile."yazi/yazi.toml".source = "${seeds}/yazi/yazi.toml";

    # ---- git -----------------------------------------------------------------------
    programs.git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push = {
          autoSetupRemote = true;
          default = "simple";
        };
        fetch = {
          prune = true;
          pruneTags = true;
        };
        rebase = {
          autoStash = true;
          autoSquash = true;
          updateRefs = true;
        };
        rerere = {
          enabled = true;
          autoUpdate = true;
        };
        diff = {
          algorithm = "histogram";
          colorMoved = "default";
          mnemonicPrefix = true;
        };
        merge.conflictStyle = "zdiff3";
        branch.sort = "-committerdate";
        tag.sort = "version:refname";
        commit.verbose = true;
        help.autocorrect = "prompt";
      };
    };
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "ansi";
      };
    };
    programs.bat = {
      enable = true;
      config = {
        theme = "ansi";
        style = "numbers,changes,header";
      };
    };

    # ---- terminal, editor, tools ---------------------------------------------------
    programs.ghostty = {
      enable = true;
      settings = {
        theme = themeName;
        font-family = "JetBrainsMono Nerd Font";
        font-size = 12;
        cursor-style = "block";
        cursor-style-blink = false;
        shell-integration = "zsh";
      };
    };
    xdg.configFile."ghostty/themes/${themeName}".source = "${t}/ghostty/${themeName}";
    programs.zed-editor = {
      enable = true;
      userSettings = builtins.fromJSON (builtins.readFile "${seeds}/zed/settings.json");
      mutableUserSettings = true;
    };
    xdg.configFile."zellij/config.kdl".source = "${seeds}/zellij/config.kdl";
    xdg.configFile."nvim/init.lua".source = "${seeds}/nvim/init.lua";
    xdg.configFile."lazygit/config.yml".source = "${seeds}/lazygit/config.yml";
    xdg.configFile."btop/themes/${themeName}.theme".source = "${t}/btop/${themeName}.theme";
    xdg.configFile."satty/config.toml".source = "${seeds}/satty/config.toml";
    xdg.configFile."mpv/mpv.conf".source = "${seeds}/mpv/mpv.conf";
    xdg.configFile."fastfetch/config.jsonc".source = "${seeds}/fastfetch/config.jsonc";
    xdg.configFile."fastfetch/logo.txt".source = "${seeds}/fastfetch/logo.txt";
    xdg.configFile."gamemode.ini".source = "${seeds}/gamemode/gamemode.ini";
    xdg.dataFile."vicinae/themes/${themeName}.toml".source = "${t}/vicinae/${themeName}.toml";

    # ---- the shell's own files -----------------------------------------------------
    # The shell watches shell-theme.json for the palette; shell.json is its config, which
    # the rail writes back (pin, unpin), so it is seeded once. btop and Vicinae rewrite
    # their files too.
    home.file.".local/state/ikigai/shell-theme.json".source = "${t}/shell.json";
    home.activation = {
      ikigaiShellConfig = seedOnce "${config.xdg.configHome}/ikigai/shell.json" "${seeds}/ikigai/shell.json";
      ikigaiBtopConfig = seedOnce "${config.xdg.configHome}/btop/btop.conf" "${seeds}/btop/btop.conf";
      ikigaiVicinaeConfig = seedOnce "${config.xdg.configHome}/vicinae/settings.json" "${seeds}/vicinae/settings.json";
      # A user-layer COSMIC theme (written by Settings) would shadow the system one.
      ikigaiCosmicTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        for f in com.system76.CosmicTheme.Dark com.system76.CosmicTheme.Dark.Builder; do
          if [ -e "${config.xdg.configHome}/cosmic/$f" ]; then
            b="${config.xdg.stateHome}/ikigai/backup/$(date +%Y%m%d-%H%M%S)"
            run mkdir -p "$b" && run mv "${config.xdg.configHome}/cosmic/$f" "$b/"
            echo "backed up ${config.xdg.configHome}/cosmic/$f to $b"
          fi
        done
      '';
    };

    # ---- look ----------------------------------------------------------------------
    gtk = {
      enable = true;
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      iconTheme = {
        name = "Ikigai";
        package = pkgs.ikigai-icons;
      };
      gtk4.theme = config.gtk.theme;
      gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
      gtk3.extraCss = builtins.readFile "${themeSrc}/gtk/gtk.css";
      gtk4.extraCss = builtins.readFile "${themeSrc}/gtk/gtk.css";
    };
    home.pointerCursor = {
      enable = true;
      name = "Ikigai";
      package = theme;
      size = 24;
      gtk.enable = true;
    };
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;
    };
    xdg.enable = true;
  };
}
