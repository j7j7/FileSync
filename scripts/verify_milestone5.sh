#!/bin/bash

# Verification Script for Milestone 5: --oneway Mode Implementation

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
PROJECT_DIR="src/FileSync.App"
APP_NAME="FileSync.App"
TEST_SRC_DIR="m5_test_src"
TEST_DEST_DIR="m5_test_dest"
LOG_FILE="milestone5_verification.log"

# --- Helper Functions ---
cleanup() {
    echo "INFO: Cleaning up temporary directories..."
    chmod -R +w "$TEST_SRC_DIR" "$TEST_DEST_DIR" 2>/dev/null || true
    rm -rf "$TEST_SRC_DIR" "$TEST_DEST_DIR" "$LOG_FILE"
}

run_app() {
    local __exit_code_var=$1
    local __output_var=$2
    shift 2
    local tmp_out=$(mktemp)
    local tmp_err=$(mktemp)
    set +e
    dotnet run --project "$PROJECT_DIR/$APP_NAME.csproj" -- "$@" --test > "$tmp_out" 2> "$tmp_err"
    local exit_status=$?
    set -e
    eval $__exit_code_var=$exit_status
    local combined_output
    combined_output=$(cat "$tmp_out" "$tmp_err")
    printf -v "$__output_var" '%s' "$combined_output"
    rm -f "$tmp_out" "$tmp_err"
    echo "--- App Output --- ($@) --- Exit: $exit_status ---" >> "$LOG_FILE"
    echo "$combined_output" >> "$LOG_FILE"
    echo "--- End App Output ---" >> "$LOG_FILE"
}

check_file_exists() {
    local file_path="$1"
    local description="$2"
    echo -n "VERIFY: $description - Existence [$file_path] ... " | tee -a "$LOG_FILE"
    if [[ -e "$file_path" ]]; then echo "PASSED (Exists)" | tee -a "$LOG_FILE"; else echo "FAILED (Does not exist)" | tee -a "$LOG_FILE"; exit 1; fi
}

check_file_not_exists() {
    local file_path="$1"
    local description="$2"
    echo -n "VERIFY: $description - Absence [$file_path] ... " | tee -a "$LOG_FILE"
    if [[ ! -e "$file_path" ]]; then echo "PASSED (Absent)" | tee -a "$LOG_FILE"; else echo "FAILED (Exists)" | tee -a "$LOG_FILE"; exit 1; fi
}

check_files_match() {
    local file1_path="$1"
    local file2_path="$2"
    local description="$3"
    echo -n "VERIFY: $description - Content Match [$file1_path vs $file2_path] ... " | tee -a "$LOG_FILE"
    if cmp -s "$file1_path" "$file2_path"; then echo "PASSED (Match)" | tee -a "$LOG_FILE"; else echo "FAILED (Content differs)" | tee -a "$LOG_FILE"; exit 1; fi
}

# --- Test Setup ---
echo "===== Starting Milestone 5 Verification =====" | tee "$LOG_FILE"
cleanup # Clean start

echo "INFO: Creating test directory structure and files..." | tee -a "$LOG_FILE"

# Create directories
mkdir -p "$TEST_SRC_DIR/sub"
# Create more complex structure in destination initially
mkdir -p "$TEST_DEST_DIR/sub"
mkdir -p "$TEST_DEST_DIR/extra_dir/nested_extra"

# File Scenarios (Similar to M3, but with destination extras to be deleted):
# 1. new_file.txt: Exists only in source -> Should be copied
# 2. common_newer.txt: Exists in both, source is newer -> Should be overwritten
# 3. common_older.txt: Exists in both, dest is newer -> Should be skipped (left alone)
# 4. extra_dest.txt: Exists only in dest -> Should be DELETED
# 5. sub/nested_new.txt: Exists only in source subdir -> Should be copied
# 6. sub/existing_dest.txt: Exists only in dest subdir -> Should be DELETED
# 7. extra_dir/: Exists only in dest -> Should be DELETED (including contents)

echo "Dest Original Newer" > "$TEST_DEST_DIR/common_newer.txt"
echo "Dest Original Older" > "$TEST_DEST_DIR/common_older.txt"
echo "Dest Extra File" > "$TEST_DEST_DIR/extra_dest.txt"
echo "Dest Sub Extra File" > "$TEST_DEST_DIR/sub/existing_dest.txt"
echo "Dest Extra Dir File" > "$TEST_DEST_DIR/extra_dir/extra_file.txt"
echo "Dest Extra Nested" > "$TEST_DEST_DIR/extra_dir/nested_extra/extra_nested.txt"

sleep 1 # Wait for timestamp difference

echo "Source New File" > "$TEST_SRC_DIR/new_file.txt"
echo "Source Updated Newer" > "$TEST_SRC_DIR/common_newer.txt"
echo "Source Older" > "$TEST_SRC_DIR/common_older.txt"
echo "Source Nested New" > "$TEST_SRC_DIR/sub/nested_new.txt"

sleep 1 # Wait again
touch "$TEST_DEST_DIR/common_older.txt" # Make dest common_older newer

echo "INFO: Test setup complete." | tee -a "$LOG_FILE"

# --- Run Sync ---
echo "INFO: Running FileSync app with --oneway..." | tee -a "$LOG_FILE"
run_app M5_EXIT_CODE M5_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --oneway

# --- Verification ---
echo "INFO: Verifying destination directory state..." | tee -a "$LOG_FILE"

# 1. Check Exit Code
if [[ "$M5_EXIT_CODE" -ne 0 ]]; then
    echo "TEST: Run Sync --oneway ... FAILED (Non-zero exit code: $M5_EXIT_CODE)" | tee -a "$LOG_FILE"
    cleanup; exit 1
fi
echo "TEST: Run Sync --oneway ... PASSED (Exit Code 0)" | tee -a "$LOG_FILE"

# 2. Verify Files Copied / Overwritten (Same as Update mode)
check_file_exists "$TEST_DEST_DIR/new_file.txt" "New file copied"
check_files_match "$TEST_SRC_DIR/new_file.txt" "$TEST_DEST_DIR/new_file.txt" "New file content"

check_file_exists "$TEST_DEST_DIR/common_newer.txt" "Newer file overwritten"
check_files_match "$TEST_SRC_DIR/common_newer.txt" "$TEST_DEST_DIR/common_newer.txt" "Newer file content"

check_file_exists "$TEST_DEST_DIR/sub/nested_new.txt" "Nested new file copied"
check_files_match "$TEST_SRC_DIR/sub/nested_new.txt" "$TEST_DEST_DIR/sub/nested_new.txt" "Nested new file content"

# 3. Verify Files Skipped (Dest newer - Same as Update mode)
check_file_exists "$TEST_DEST_DIR/common_older.txt" "Older file (dest newer) exists"
# Check content is still the original destination content (touch doesn't change content)
if grep -q "Dest Original Older" "$TEST_DEST_DIR/common_older.txt"; then
    echo "VERIFY: Older file content unchanged ... PASSED" | tee -a "$LOG_FILE"
else
    echo "VERIFY: Older file content unchanged ... FAILED" | tee -a "$LOG_FILE"
    exit 1
fi

# 4. Verify Extra Destination Files/Dirs DELETED
check_file_not_exists "$TEST_DEST_DIR/extra_dest.txt" "Extra dest file deleted"
check_file_not_exists "$TEST_DEST_DIR/sub/existing_dest.txt" "Extra dest sub-file deleted"
check_file_not_exists "$TEST_DEST_DIR/extra_dir" "Extra dest directory deleted"
check_file_not_exists "$TEST_DEST_DIR/extra_dir/extra_file.txt" "Extra dest dir content deleted"

# 5. Verify Source Structure Exists
check_file_exists "$TEST_DEST_DIR/sub" "Source subdirectory exists"

echo "INFO: Destination state verification successful." | tee -a "$LOG_FILE"

# --- Cleanup ---
cleanup

echo "
===== Milestone 5 Verification PASSED =====" | tee -a "$LOG_FILE"
exit 0 