export ASDF_PATH="${HOME}/.asdf"

# Install asdf if not installed
if [[ ! "$(command -v asdf)" ]]; then
    echo "Installing ASDF..."
    git clone https://github.com/asdf-vm/asdf.git "${ASDF_PATH}"
fi

# Check for the global .tool-versions file employed by asdf
# to determine which versions of tools to install
if [[ ! -f "${HOME}/.tool-versions" ]]; then
    echo ".tool-versions file not found"
    exit 1
fi

# This function sets up the language environment using asdf
setup_language()
                 {
    local language=$1
    local version

    # Get version from .tool-versions file
    version=$(awk -v pattern="${language}" '$0 ~ pattern { print $2 }' "${HOME}/.tool-versions")

    # If asdf is installed, use it to manage the language version
    if command -v asdf &> /dev/null; then
        # Install the language plugin for asdf if not installed
        if ! asdf plugin list | grep -q "${language}"; then
            echo "Installing ASDF ${language} plugin..."
            asdf plugin add "${language}"
        fi

        # Install global asdf language version (if not already installed)
        if ! asdf list "${language}" | grep -q "${version}"; then
            ARCH="$(uname -m)"
            OS="$(uname | tr '[:upper:]' '[:lower:]')"

            echo "Installing ${language} ${version} for ${ARCH} on ${OS}"

            if [[ "${ARCH}" == "arm64" && "${OS}" == "darwin" ]]; then
                echo "ARM architecture detected"
                # Specify architecture
                eval "ASDF_${language}_OVERWRITE_ARCH=${ARCH}"
                asdf install "${language}" "${version}"
            else
                # Install language without specifying architecture
                asdf install "${language}" "${version}"
            fi
            # Reshim language version
            asdf reshim "${language}" "${version}"
        fi

        # Set the global version of the language
        asdf global "${language}" "${version}"
    else
        echo "asdf not installed. Using system ${language} version."
    fi
}