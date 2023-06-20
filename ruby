# Global asdf ruby version
RB_VER='3.1.2'
export RB_VER
ASDF_PATH="${HOME}/.asdf"
export ASDF_PATH

# If asdf is installed, use it to manage Ruby versions
if command -v asdf &> /dev/null; then
    # Install the Ruby plugin for asdf if not installed
    if ! asdf plugin list | grep -q 'ruby'; then
        echo "Installing ASDF ruby plugin..."
        asdf plugin add ruby
    fi

    # Install global asdf Ruby version (if not already installed)
    if ! asdf list ruby | grep -q "${RB_VER}"; then
        ARCH="$(uname -m)"
        OS="$(uname | tr '[:upper:]' '[:lower:]')"

        echo "Installing Ruby ${RB_VER} for ${ARCH} on ${OS}"

        if [[ "${ARCH}" == "arm64" && "${OS}" == "darwin" ]]; then
            echo "ARM architecture detected"
            # Specify architecture
            ASDF_RUBY_OVERWRITE_ARCH="${ARCH}" \
                asdf install ruby "${RB_VER}"
        else
            # Install Ruby without specifying architecture
            asdf install ruby "${RB_VER}"
        fi
        # Use ruby command without needing to provide a suffix
        asdf reshim ruby "${RB_VER}"
    fi

    # Set the global version of Ruby
    asdf global ruby "${RB_VER}"

else
    echo "asdf not installed. Using system Ruby version."
fi
