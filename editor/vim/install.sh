#!/bin/sh
# Install NExT syntax highlighting for Vim/Neovim
#
# Usage:
#   ./install-vim.sh          # install to ~/.vim
#   ./install-vim.sh /path    # install to custom path

DEST="${1:-$HOME/.vim}"

mkdir -p "$DEST/syntax" "$DEST/ftdetect"
cp syntax/nxt.vim "$DEST/syntax/"
cp ftdetect/nxt.vim "$DEST/ftdetect/"

echo "Installed to $DEST"
echo "  $DEST/syntax/nxt.vim"
echo "  $DEST/ftdetect/nxt.vim"
