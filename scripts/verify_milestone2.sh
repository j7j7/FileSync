#!/bin/bash

# Verification Script for Milestone 2: Core Directory Scanning

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
PROJECT_DIR="src/FileSync.App"
APP_NAME="FileSync.App"
TEST_SRC_DIR="m2_test_src"
TEST_DEST_DIR="m2_test_dest"
LOG_FILE="milestone2_verification.log"

# --- Helper Functions (Copied/adapted from verify_milestone1.sh) ---
cleanup() {
    echo "INFO: Cleaning up temporary directories..."
    rm -rf "$TEST_SRC_DIR" "$TEST_DEST_DIR" "$LOG_FILE"
}

run_app() {
    local __exit_code_var=$1
    local __output_var=$2
    shift 2
    local tmp_out=$(mktemp)
    local tmp_err=$(mktemp)
    if dotnet run --project "$PROJECT_DIR/$APP_NAME.csproj" -- "$@" > "$tmp_out" 2> "$tmp_err"; then
        eval $__exit_code_var=0
    else
        local exit_status=$?
        eval $__exit_code_var=$exit_status
    fi
    local combined_output
    combined_output=$(cat "$tmp_out" "$tmp_err")
    printf -v "$__output_var" '%s' "$combined_output"
    rm -f "$tmp_out" "$tmp_err"
}

check_result() {
    local description="$1"
    local expected_code="$2"
    local actual_code="$3"
    local output="$4"
    shift 4
    local expected_texts=("$@")

    echo -n "TEST: $description ... " | tee -a "$LOG_FILE"
    if [[ "$actual_code" -ne "$expected_code" ]]; then
        echo "FAILED (Exit Code: $actual_code, Expected: $expected_code)" | tee -a "$LOG_FILE"
        echo "Output:"; echo "$output" | tee -a "$LOG_FILE"
        exit 1
    fi
    for text in "${expected_texts[@]}"; do
        if ! echo "$output" | grep -qF -- "$text"; then # Use -- to handle texts starting with -
            echo "FAILED (Output missing text: '$text')" | tee -a "$LOG_FILE"
            echo "Output:"; echo "$output" | tee -a "$LOG_FILE"
            exit 1
        fi
    done
    echo "PASSED" | tee -a "$LOG_FILE"
}

# --- Test Setup ---
echo "===== Starting Milestone 2 Verification =====" | tee "$LOG_FILE"
cleanup # Clean up any previous runs

echo "INFO: Creating test directory structure..." | tee -a "$LOG_FILE"

# Source: file1.txt, sub1/file2.txt, sub1/sub2/file3.txt, empty_sub/
# Total: 3 files + 3 folders = 6 items
mkdir -p "$TEST_SRC_DIR/sub1/sub2"
mkdir -p "$TEST_SRC_DIR/empty_sub"
touch "$TEST_SRC_DIR/file1.txt"
touch "$TEST_SRC_DIR/sub1/file2.txt"
touch "$TEST_SRC_DIR/sub1/sub2/file3.txt"
EXPECTED_SRC_ITEMS=6

# Destination: fileA.txt, subA/fileB.txt
# Total: 2 files + 1 folder = 3 items
mkdir -p "$TEST_DEST_DIR/subA"
touch "$TEST_DEST_DIR/fileA.txt"
touch "$TEST_DEST_DIR/subA/fileB.txt"
EXPECTED_DEST_ITEMS=3

echo "INFO: Test directories created." | tee -a "$LOG_FILE"

# --- Main Test ---

echo "INFO: Running FileSync app for scanning test..." | tee -a "$LOG_FILE"
run_app M2_EXIT_CODE M2_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR"

# Verify exit code is 0 (success)
if [[ "$M2_EXIT_CODE" -ne 0 ]]; then
    echo "TEST: Run Scan ... FAILED (Non-zero exit code: $M2_EXIT_CODE)" | tee -a "$LOG_FILE"
    echo "Output:"; echo "$M2_OUTPUT" | tee -a "$LOG_FILE"
    cleanup
    exit 1
fi

# Verify output contains the expected item counts
check_result "Verify Scan Output" 0 "$M2_EXIT_CODE" "$M2_OUTPUT" \
    "Found $EXPECTED_SRC_ITEMS items in source." \
    "Found $EXPECTED_DEST_ITEMS items in destination." \
    "Comparison and sync logic will go here"

# Note: Testing inaccessible directories automatically is complex and platform-dependent.
# Manual testing might be required for full coverage of error handling.

echo "INFO: Directory scanning verification successful." | tee -a "$LOG_FILE"

# --- Cleanup ---
cleanup

echo "===== Milestone 2 Verification PASSED =====" | tee -a "$LOG_FILE"
exit 0 