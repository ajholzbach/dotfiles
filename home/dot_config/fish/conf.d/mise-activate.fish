# Homebrew's mise adds vendor_conf.d/mise-activate.fish, which runs mise activate
# config.fish already runs mise activate, so mise would activate twice
# Fish skips a vendor conf.d file when this folder has a file with the same name
# This file is empty on purpose, to turn off the Homebrew copy
