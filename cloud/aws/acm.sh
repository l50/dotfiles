# shellcheck shell=bash

# Delete Failed ACM Certificates Based on Criteria
#
# This function lists and deletes AWS ACM certificates that are in the FAILED status and match a specified selection criteria.
# The deletion process is done in parallel for efficiency.
#
# Usage:
#   delete_failed_acm_certificates "selection-criteria"
#   where "selection-criteria" is the optional string used to match certificate ARNs or domain names.
#
# Output:
#   Outputs the progress of deleting certificates, including any errors encountered.
#
# Example(s):
#   delete_failed_acm_certificates
#   delete_failed_acm_certificates "example.com"
#   delete_failed_acm_certificates "arn:aws:acm:us-east-1:123456789012:certificate"
delete_failed_acm_certificates() {
    local selection_criteria=${1:-}

    # Store certificates in temporary file to check if empty
    local temp_file
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT

    aws acm list-certificates \
        --certificate-statuses FAILED \
        --query 'CertificateSummaryList[*].[CertificateArn,DomainName]' \
        --output text \
        | grep -i "${selection_criteria}" \
        | awk '{print $1}' > "$temp_file"

    if [[ ! -s "$temp_file" ]]; then
        echo "No failed certificates found matching the criteria."
        return 0
    fi

    # Process certificates in parallel
    while IFS= read -r cert_arn; do
        (
            echo "Deleting certificate: ${cert_arn}"
            if aws acm delete-certificate --certificate-arn "$cert_arn"; then
                echo "Successfully deleted certificate: ${cert_arn}"
            else
                echo "Failed to delete certificate: ${cert_arn}"
            fi
        ) &
    done < "$temp_file"

    wait
    echo "Deletion of failed certificates completed."
}
