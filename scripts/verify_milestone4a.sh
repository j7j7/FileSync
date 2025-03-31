#!/bin/bash

# Verification Script for Milestone 4a: --update Option

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
PROJECT_DIR="src/FileSync.App"
APP_NAME="FileSync.App"
TEST_SRC_DIR="m4a_test_src"
TEST_DEST_DIR="m4a_test_dest"
LOG_FILE="milestone4a_verification.log"

# --- Helper Functions (Mostly from verify_milestone3.sh) ---
cleanup() {
    echo "INFO: Cleaning up temporary directories..."
    chmod -R +w "$TEST_SRC_DIR" "$TEST_DEST_DIR" 2>/dev/null || true
    rm -rf "$TEST_SRC_DIR" "$TEST_DEST_DIR" "$LOG_FILE" \
           "$TEST_DEST_DIR"/*.orig 2>/dev/null || true
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
    echo "--- App Output ---" >> "$LOG_FILE"
    echo "$combined_output" >> "$LOG_FILE"
    echo "--- End App Output ---" >> "$LOG_FILE"
}

check_file_exists() {
    local file_path="$1"
    local description="$2"
    echo -n "VERIFY: $description - Existence [$file_path] ... " | tee -a "$LOG_FILE"
    if [[ -e "$file_path" ]]; then echo "PASSED (Exists)" | tee -a "$LOG_FILE"; else echo "FAILED (Does not exist)" | tee -a "$LOG_FILE"; exit 1; fi
}

check_files_match() {
    local file1_path="$1"
    local file2_path="$2"
    local description="$3"
    echo -n "VERIFY: $description - Content Match [$file1_path vs $file2_path] ... " | tee -a "$LOG_FILE"
    if cmp -s "$file1_path" "$file2_path"; then echo "PASSED (Match)" | tee -a "$LOG_FILE"; else echo "FAILED (Content differs)" | tee -a "$LOG_FILE"; exit 1; fi
}

# --- Test Setup Function ---
setup_test_files() {
    echo "INFO: Creating test directory structure and files..." | tee -a "$LOG_FILE"
    mkdir -p "$TEST_SRC_DIR/sub"
    mkdir -p "$TEST_DEST_DIR/sub"

    echo "Dest Original Content" > "$TEST_DEST_DIR/common_newer.txt"
    echo "Dest Original Content" > "$TEST_DEST_DIR/common_older.txt"
    echo "Dest Only Content" > "$TEST_DEST_DIR/extra_dest.txt"
    echo "Dest Sub Only Content" > "$TEST_DEST_DIR/sub/existing_dest.txt"

    sleep 1 # Reduced sleep time, might be sufficient

    echo "Source New File Content" > "$TEST_SRC_DIR/new_file.txt"
    echo "Source Newer Content" > "$TEST_SRC_DIR/common_newer.txt"
    echo "Source Older Content" > "$TEST_SRC_DIR/common_older.txt"
    echo "Source Nested New Content" > "$TEST_SRC_DIR/sub/nested_new.txt"

    sleep 1 # Reduced sleep time
    touch "$TEST_DEST_DIR/common_older.txt"

    cp "$TEST_DEST_DIR/common_older.txt" "$TEST_DEST_DIR/common_older.txt.orig"
    cp "$TEST_DEST_DIR/extra_dest.txt" "$TEST_DEST_DIR/extra_dest.txt.orig"
    cp "$TEST_DEST_DIR/sub/existing_dest.txt" "$TEST_DEST_DIR/sub/existing_dest.txt.orig"

    echo "INFO: Test setup complete." | tee -a "$LOG_FILE"
}

# --- Verification Function ---
verify_destination_state() {
    local test_label="$1"
    echo "INFO: Verifying destination directory state ($test_label)..." | tee -a "$LOG_FILE"
    # Files Copied / Overwritten
    check_file_exists "$TEST_DEST_DIR/new_file.txt" "New file copied ($test_label)"
    check_files_match "$TEST_SRC_DIR/new_file.txt" "$TEST_DEST_DIR/new_file.txt" "New file content ($test_label)"
    check_file_exists "$TEST_DEST_DIR/common_newer.txt" "Newer file overwritten ($test_label)"
    check_files_match "$TEST_SRC_DIR/common_newer.txt" "$TEST_DEST_DIR/common_newer.txt" "Newer file content ($test_label)"
    check_file_exists "$TEST_DEST_DIR/sub/nested_new.txt" "Nested new file copied ($test_label)"
    check_files_match "$TEST_SRC_DIR/sub/nested_new.txt" "$TEST_DEST_DIR/sub/nested_new.txt" "Nested new file content ($test_label)"
    # Files Skipped (Content Unchanged)
    check_file_exists "$TEST_DEST_DIR/common_older.txt" "Older file skipped ($test_label)"
    check_files_match "$TEST_DEST_DIR/common_older.txt.orig" "$TEST_DEST_DIR/common_older.txt" "Older file content unchanged ($test_label)"
    check_file_exists "$TEST_DEST_DIR/extra_dest.txt" "Extra dest file skipped ($test_label)"
    check_files_match "$TEST_DEST_DIR/extra_dest.txt.orig" "$TEST_DEST_DIR/extra_dest.txt" "Extra dest file content unchanged ($test_label)"
    check_file_exists "$TEST_DEST_DIR/sub/existing_dest.txt" "Extra dest sub-file skipped ($test_label)"
    check_files_match "$TEST_DEST_DIR/sub/existing_dest.txt.orig" "$TEST_DEST_DIR/sub/existing_dest.txt" "Extra dest sub-file content unchanged ($test_label)"
    # Directories
    check_file_exists "$TEST_DEST_DIR/sub" "Subdirectory exists ($test_label)"
    echo "INFO: Destination state verification successful ($test_label)." | tee -a "$LOG_FILE"
}


# --- Main Script ---
echo "===== Starting Milestone 4a Verification =====" | tee "$LOG_FILE"

# --- Test 1: Default Mode (Implicit Update) ---
echo "
--- Test 1: Running with default mode (no mode flag) ---
" | tee -a "$LOG_FILE"
cleanup && setup_test_files
run_app M4A_T1_EXIT M4A_T1_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR"
if [[ "$M4A_T1_EXIT" -ne 0 ]]; then echo "TEST 1 FAILED (Exit Code: $M4A_T1_EXIT)"; cleanup; exit 1; fi
verify_destination_state "Test 1 (Default)"
echo "--- Test 1 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 2: Explicit --update Mode ---
echo "
--- Test 2: Running with explicit --update flag ---
" | tee -a "$LOG_FILE"
cleanup && setup_test_files
run_app M4A_T2_EXIT M4A_T2_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --update
if [[ "$M4A_T2_EXIT" -ne 0 ]]; then echo "TEST 2 FAILED (Exit Code: $M4A_T2_EXIT)"; cleanup; exit 1; fi
verify_destination_state "Test 2 (--update)"
echo "--- Test 2 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 3: Check --help Output ---
echo "
--- Test 3: Checking --help output ---
" | tee -a "$LOG_FILE"
run_app M4A_T3_EXIT M4A_T3_OUTPUT --help
if [[ "$M4A_T3_EXIT" -ne 0 ]]; then echo "TEST 3 FAILED (Exit Code: $M4A_T3_EXIT)"; cleanup; exit 1; fi
if echo "$M4A_T3_OUTPUT" | grep -q -- "--update"; then
    echo "VERIFY: --help contains --update ... PASSED" | tee -a "$LOG_FILE"
else
    echo "VERIFY: --help contains --update ... FAILED" | tee -a "$LOG_FILE"
    echo "$M4A_T3_OUTPUT" >> "$LOG_FILE"
    cleanup; exit 1
fi
echo "--- Test 3 PASSED ---" | tee -a "$LOG_FILE"

# --- Cleanup ---
cleanup

echo "
===== Milestone 4a Verification PASSED =====" | tee -a "$LOG_FILE"
exit 0 