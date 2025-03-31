#!/bin/bash

# Verification Script for Milestone 3: Basic Sync Logic (--update mode) & File Copying

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
PROJECT_DIR="src/FileSync.App"
APP_NAME="FileSync.App"
TEST_SRC_DIR="m3_test_src"
TEST_DEST_DIR="m3_test_dest"
LOG_FILE="milestone3_verification.log"

# --- Helper Functions ---
cleanup() {
    echo "INFO: Cleaning up temporary directories..."
    # Make files writable before deleting just in case
    chmod -R +w "$TEST_SRC_DIR" "$TEST_DEST_DIR" 2>/dev/null || true
    rm -rf "$TEST_SRC_DIR" "$TEST_DEST_DIR" "$LOG_FILE"
}

run_app() {
    local __exit_code_var=$1
    local __output_var=$2
    shift 2
    local tmp_out=$(mktemp)
    local tmp_err=$(mktemp)
    # Run with --log parameter once implemented, for now capture console
    if dotnet run --project "$PROJECT_DIR/$APP_NAME.csproj" -- "$@" --test > "$tmp_out" 2> "$tmp_err"; then
        eval $__exit_code_var=0
    else
        local exit_status=$?
        eval $__exit_code_var=$exit_status
    fi
    local combined_output
    combined_output=$(cat "$tmp_out" "$tmp_err")
    printf -v "$__output_var" '%s' "$combined_output"
    rm -f "$tmp_out" "$tmp_err"
    echo "--- App Output ---" >> "$LOG_FILE"
    echo "$combined_output" >> "$LOG_FILE"
    echo "--- End App Output ---" >> "$LOG_FILE"
}

# Function to check if a file exists
check_file_exists() {
    local file_path="$1"
    local description="$2"
    echo -n "VERIFY: $description - Existence [$file_path] ... " | tee -a "$LOG_FILE"
    if [[ -e "$file_path" ]]; then
        echo "PASSED (Exists)" | tee -a "$LOG_FILE"
    else
        echo "FAILED (Does not exist)" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Function to check if a file does NOT exist
check_file_not_exists() {
    local file_path="$1"
    local description="$2"
    echo -n "VERIFY: $description - Absence [$file_path] ... " | tee -a "$LOG_FILE"
    if [[ ! -e "$file_path" ]]; then
        echo "PASSED (Absent)" | tee -a "$LOG_FILE"
    else
        echo "FAILED (Exists)" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Function to compare two files
check_files_match() {
    local file1_path="$1"
    local file2_path="$2"
    local description="$3"
    echo -n "VERIFY: $description - Content Match [$file1_path vs $file2_path] ... " | tee -a "$LOG_FILE"
    if cmp -s "$file1_path" "$file2_path"; then
        echo "PASSED (Match)" | tee -a "$LOG_FILE"
    else
        echo "FAILED (Content differs)" | tee -a "$LOG_FILE"
        # diff "$file1_path" "$file2_path" | tee -a "$LOG_FILE" # Optionally show diff
        exit 1
    fi
}


# --- Test Setup ---
echo "===== Starting Milestone 3 Verification =====" | tee "$LOG_FILE"
cleanup # Clean up any previous runs

echo "INFO: Creating test directory structure and files..." | tee -a "$LOG_FILE"

# Create directories
mkdir -p "$TEST_SRC_DIR/sub"
mkdir -p "$TEST_DEST_DIR/sub"

# File Scenarios:
# 1. new_file.txt: Exists only in source -> Should be copied
# 2. common_newer.txt: Exists in both, source is newer -> Should be overwritten
# 3. common_older.txt: Exists in both, dest is newer -> Should be skipped (left alone)
# 4. extra_dest.txt: Exists only in dest -> Should be skipped (left alone)
# 5. sub/nested_new.txt: Exists only in source subdir -> Should be copied (dir created if needed)
# 6. sub/existing_dest.txt: Exists only in dest subdir -> Should be skipped (left alone)

echo "Dest Original Content" > "$TEST_DEST_DIR/common_newer.txt"
echo "Dest Original Content" > "$TEST_DEST_DIR/common_older.txt"
echo "Dest Only Content" > "$TEST_DEST_DIR/extra_dest.txt"
echo "Dest Sub Only Content" > "$TEST_DEST_DIR/sub/existing_dest.txt"

echo "INFO: Waiting briefly to ensure timestamp differences..." | tee -a "$LOG_FILE"
sleep 2 # Wait 2 seconds

echo "Source New File Content" > "$TEST_SRC_DIR/new_file.txt"
echo "Source Newer Content" > "$TEST_SRC_DIR/common_newer.txt"
echo "Source Older Content" > "$TEST_SRC_DIR/common_older.txt"
echo "Source Nested New Content" > "$TEST_SRC_DIR/sub/nested_new.txt"

# Make dest common_older.txt newer than source common_older.txt
# (Can't reliably set specific old times easily, so make dest newer than source now)
sleep 2 # Wait again
touch "$TEST_DEST_DIR/common_older.txt"

# Store original content of files that should NOT change
cp "$TEST_DEST_DIR/common_older.txt" "$TEST_DEST_DIR/common_older.txt.orig"
cp "$TEST_DEST_DIR/extra_dest.txt" "$TEST_DEST_DIR/extra_dest.txt.orig"
cp "$TEST_DEST_DIR/sub/existing_dest.txt" "$TEST_DEST_DIR/sub/existing_dest.txt.orig"

echo "INFO: Test setup complete." | tee -a "$LOG_FILE"

# --- Run Sync ---
echo "INFO: Running FileSync app (--update mode implied)..." | tee -a "$LOG_FILE"
run_app M3_EXIT_CODE M3_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR"

# --- Verification ---
echo "INFO: Verifying destination directory state..." | tee -a "$LOG_FILE"

# 1. Check Exit Code
if [[ "$M3_EXIT_CODE" -ne 0 ]]; then
    echo "TEST: Run Sync ... FAILED (Non-zero exit code: $M3_EXIT_CODE)" | tee -a "$LOG_FILE"
    cleanup; exit 1
fi
echo "TEST: Run Sync ... PASSED (Exit Code 0)" | tee -a "$LOG_FILE"

# 2. Verify Files Copied / Overwritten
check_file_exists "$TEST_DEST_DIR/new_file.txt" "New file copied"
check_files_match "$TEST_SRC_DIR/new_file.txt" "$TEST_DEST_DIR/new_file.txt" "New file content"

check_file_exists "$TEST_DEST_DIR/common_newer.txt" "Newer file overwritten"
check_files_match "$TEST_SRC_DIR/common_newer.txt" "$TEST_DEST_DIR/common_newer.txt" "Newer file content"

check_file_exists "$TEST_DEST_DIR/sub/nested_new.txt" "Nested new file copied"
check_files_match "$TEST_SRC_DIR/sub/nested_new.txt" "$TEST_DEST_DIR/sub/nested_new.txt" "Nested new file content"

# 3. Verify Files Skipped (Content Unchanged)
check_file_exists "$TEST_DEST_DIR/common_older.txt" "Older file skipped"
check_files_match "$TEST_DEST_DIR/common_older.txt.orig" "$TEST_DEST_DIR/common_older.txt" "Older file content unchanged"

check_file_exists "$TEST_DEST_DIR/extra_dest.txt" "Extra dest file skipped"
check_files_match "$TEST_DEST_DIR/extra_dest.txt.orig" "$TEST_DEST_DIR/extra_dest.txt" "Extra dest file content unchanged"

check_file_exists "$TEST_DEST_DIR/sub/existing_dest.txt" "Extra dest sub-file skipped"
check_files_match "$TEST_DEST_DIR/sub/existing_dest.txt.orig" "$TEST_DEST_DIR/sub/existing_dest.txt" "Extra dest sub-file content unchanged"

# 4. Verify Directories
check_file_exists "$TEST_DEST_DIR/sub" "Subdirectory exists" # Should exist from setup or be created by sync

echo "INFO: Destination state verification successful." | tee -a "$LOG_FILE"

# --- Cleanup ---
cleanup

echo "===== Milestone 3 Verification PASSED =====" | tee -a "$LOG_FILE"
exit 0 