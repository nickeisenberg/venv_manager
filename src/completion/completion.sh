if [[ -n $ZSH_VERSION ]]; then
    . "${VENVMAN_ROOT_DIR}/venvman/src/completion/zsh_completion.zsh"
elif [[ -n $BASH_VERSION ]]; then
    . "${VENVMAN_ROOT_DIR}/venvman/src/completion/bash_completion.sh"
fi
