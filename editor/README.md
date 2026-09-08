# NExT Editor Support

## Vim / Neovim

    cd editor/vim
    ./install-vim.sh            # installs to ~/.vim
    ./install-vim.sh ~/.config/nvim  # for Neovim

Or manually copy:
    syntax/nxt.vim    →  ~/.vim/syntax/nxt.vim
    ftdetect/nxt.vim  →  ~/.vim/ftdetect/nxt.vim

## VS Code

    cd editor/vscode
    code --install-extension .

Or open in VS Code and press F1 → "Extensions: Install from VSIX..."

## What's highlighted

- **Nouns** (CamelCase) — type names, highlighted as types
- **Adjectives** (snake_case) — attribute names, highlighted as identifiers
- **Strings** — double-quoted with escape sequences
- **Numbers** — integers and floats
- **Booleans** — true/false
- **Symbols** — @references
- **Comments** — # to end of line
- **Template syntax** — ${VAR}, %Directive, %function
