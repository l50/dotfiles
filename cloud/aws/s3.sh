# Clean Up and Delete S3 Buckets Based on Criteria
#
# This function lists and deletes S3 buckets that match a specified selection criteria.
# It first deletes all objects (including versions and delete markers) within each bucket,
# and then deletes the bucket itself. The deletion process is done in parallel for efficiency.
#
# Usage:
#   clear_and_delete_s3_buckets "bucket-selection-criteria"
#   where "bucket-selection-criteria" is the string used to match bucket names.
#
# Output:
#   Outputs the progress of deleting objects and buckets, including any errors encountered.
#
# Example(s):
#   clear_and_delete_s3_buckets "ttpforge-bucket"
#   clear_and_delete_s3_buckets "attack-box-bucket"
#   clear_and_delete_s3_buckets "atomic-red-team-bucket"
#   clear_and_delete_s3_buckets "my-example-bucket"
clear_and_delete_s3_buckets() {
    local bucket_selection_criteria=$1

    if [[ -z "$bucket_selection_criteria" ]]; then
        echo "No bucket selection criteria provided. Usage: clean_up_s3_buckets <bucket-selection-criteria>"
        return 1
    fi

    # List all buckets that match the selection criteria
    local buckets=()
    while IFS= read -r line; do
        buckets+=("$line")
    done < <(aws s3 ls | grep -i "$bucket_selection_criteria" | awk '{print $3}')

    # Iterate through each bucket and delete its contents and the bucket itself
    for bucket in "${buckets[@]}"; do
        (
            echo "Deleting objects from bucket: ${bucket}"

            # Remove all versions of all objects from the bucket
            aws s3api list-object-versions --bucket "$bucket" --output json | jq -r '.Versions[] | .Key + " " + .VersionId' | xargs -P 10 -n 2 aws s3api delete-object --bucket "$bucket" --key {} --version-id {}

            # Remove all delete markers (needed for versioned buckets)
            aws s3api list-object-versions --bucket "$bucket" --output json | jq -r '.DeleteMarkers[] | .Key + " " + .VersionId' | xargs -P 10 -n 2 aws s3api delete-object --bucket "$bucket" --key {} --version-id {}

            echo "Deleting bucket: ${bucket}"

            # Delete the bucket
            aws s3 rb s3://"$bucket" --force
        ) &
    done
    wait
}

# Download Bucket
#
# Syncs the contents of the specified Amazon S3 bucket to the
# specified local destination directory or to the current directory
# if no destination is provided.
#
# Usage:
#   download_bucket [bucket-name] [destination-directory]
#
# Output:
#   Syncs the files from the S3 bucket to the local destination.
#
# Example(s):
#   download_bucket "mybucket" "$HOME"
#   download_bucket "mybucket"
download_bucket() {
	bucket="${1}"
	if [[ -z "${bucket}" ]]; then
		echo "You need to supply a bucket!"
		echo "Example: download_bucket mybucket $HOME"
		return 1
	fi
	dest="${2}"
	if [[ -z "${dest}" ]]; then
		dest='.'
	fi

	aws s3 sync "s3://${1}" "${dest}"
}