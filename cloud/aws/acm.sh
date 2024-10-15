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

    # List all failed certificates that match the selection criteria
    local certificates=()
    while IFS= read -r line; do
        certificates+=("$line")
    done < <(
        aws acm list-certificates --certificate-statuses FAILED --query 'CertificateSummaryList[*].[CertificateArn,DomainName]' --output text \
            | grep -i "${selection_criteria}" | awk '{print $1}'
    )

    if [[ ${#certificates[@]} -eq 0 ]]; then
        echo "No failed certificates found matching the criteria."
        return 0
    fi

    # Iterate through each certificate and delete it
    for cert_arn in "${certificates[@]}"; do
        (   
            echo "Deleting certificate: ${cert_arn}"

            aws acm delete-certificate --certificate-arn "$cert_arn"
            if [[ $? -eq 0 ]]; then
                echo "Successfully deleted certificate: ${cert_arn}"
            else
                echo "Failed to delete certificate: ${cert_arn}"
            fi
        ) &
    done
    wait
    echo "Deletion of failed certificates completed."
}
