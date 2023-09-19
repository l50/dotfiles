#!/usr/bin/env bash

ASDF_PATH="${HOME}/.asdf"
export PATH=$PATH:$ASDF_PATH

# Install asdf if not installed
if [[ ! -d "${ASDF_PATH}" ]]; then
    echo "Installing ASDF..."
    git clone https://github.com/asdf-vm/asdf.git "${ASDF_PATH}"
fi

# Source asdf.sh to add asdf to current shell session
if [[ -f "${ASDF_PATH}/asdf.sh" ]]; then
    # shellcheck source=/dev/null
    . "${ASDF_PATH}/asdf.sh"
else
    echo "asdf.sh not found. Please check your ASDF installation."
    exit 1
fi

# Check for the global .tool-versions file employed by asdf
# to determine which versions of tools to install
if [[ ! -f "${HOME}/.tool-versions" ]]; then
    echo ".tool-versions file not found"
    exit 1
fi

# This function sets up the language environment using asdf
setup_language() {
    local language=$1
    local scope=$2 # 'global' or 'local'
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

        # Set the global or local version of the language
        if [[ "${scope}" == "global" ]]; then
            asdf global "${language}" "${version}"
    elif     [[ "${scope}" == "local" ]]; then
            asdf local "${language}" "${version}"
    else
            echo "Invalid scope. Please use 'global' or 'local'."
    fi
  else
        echo "asdf not installed. Using system ${language} version."
  fi
}
