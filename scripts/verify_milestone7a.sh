#!/bin/bash

# Verification Script for Milestone 7a: --test Flag and Conditional Logging

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
PROJECT_DIR="src/FileSync.App"
APP_NAME="FileSync.App"
TEST_SRC_DIR="m7a_test_src"
TEST_DEST_DIR="m7a_test_dest"
LOG_FILE="milestone7a_verification.log"

# --- Helper Functions ---
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
    set +e
    dotnet run --project "$PROJECT_DIR/$APP_NAME.csproj" -- "$@" > "$tmp_out" 2> "$tmp_err"
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

check_output_contains() {
    local output="$1"; local expected_text="$2"; local description="$3"
    echo -n "VERIFY: $description - Output contains '$expected_text' ... " | tee -a "$LOG_FILE"
    if echo "$output" | grep -qF -- "$expected_text"; then echo "PASSED" | tee -a "$LOG_FILE"; else echo "FAILED" | tee -a "$LOG_FILE"; echo "Output was:"; echo "$output" | tee -a "$LOG_FILE"; exit 1; fi
}

check_output_does_not_contain() {
    local output="$1"; local unexpected_text="$2"; local description="$3"
    echo -n "VERIFY: $description - Output does NOT contain '$unexpected_text' ... " | tee -a "$LOG_FILE"
    if echo "$output" | grep -qF -- "$unexpected_text"; then echo "FAILED" | tee -a "$LOG_FILE"; echo "Output was:"; echo "$output" | tee -a "$LOG_FILE"; exit 1; else echo "PASSED" | tee -a "$LOG_FILE"; fi
}

check_exit_code() {
    local actual_code="$1"; local expected_code="$2"; local description="$3"
    echo -n "VERIFY: $description - Exit code [$actual_code vs $expected_code] ... " | tee -a "$LOG_FILE"
    if [[ "$actual_code" -eq "$expected_code" ]]; then echo "PASSED" | tee -a "$LOG_FILE"; else echo "FAILED (Expected $expected_code)" | tee -a "$LOG_FILE"; exit 1; fi
}

# --- Main Script ---
echo "===== Starting Milestone 7a Verification =====" | tee "$LOG_FILE"

# --- Test 1: Check --help Output ---
echo "
--- Test 1: Checking --help output ---
" | tee -a "$LOG_FILE"
run_app M7A_T1_EXIT M7A_T1_OUTPUT --help
check_exit_code "$M7A_T1_EXIT" 0 "Test 1 Help Exit Code"
check_output_contains "$M7A_T1_OUTPUT" "--test" "Test 1 Help Output"
echo "--- Test 1 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 2: Run WITH --test flag ---
echo "
--- Test 2: Running WITH --test ---
" | tee -a "$LOG_FILE"
cleanup && mkdir -p "$TEST_SRC_DIR" "$TEST_DEST_DIR"
touch "$TEST_SRC_DIR/file1.txt"
run_app M7A_T2_EXIT M7A_T2_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --test
check_exit_code "$M7A_T2_EXIT" 0 "Test 2 (--test) Exit Code"
# Check for specific log messages that should ONLY appear in test mode
check_output_contains "$M7A_T2_OUTPUT" "Comparing source and destination items" "Test 2 Log Msg 1"
check_output_contains "$M7A_T2_OUTPUT" "Scheduling copy/create (new): file1.txt" "Test 2 Log Msg 2"
check_output_contains "$M7A_T2_OUTPUT" "Executing CopyFile actions" "Test 2 Log Msg 3"
check_output_contains "$M7A_T2_OUTPUT" "Copying file: file1.txt to" "Test 2 Log Msg 4"
check_output_contains "$M7A_T2_OUTPUT" "Synchronization actions finished." "Test 2 Log Msg 5"
echo "--- Test 2 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 3: Run WITHOUT --test flag ---
echo "
--- Test 3: Running WITHOUT --test ---
" | tee -a "$LOG_FILE"
cleanup && mkdir -p "$TEST_SRC_DIR" "$TEST_DEST_DIR"
touch "$TEST_SRC_DIR/file1.txt"
run_app M7A_T3_EXIT M7A_T3_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR"
check_exit_code "$M7A_T3_EXIT" 0 "Test 3 (no --test) Exit Code"
# Check that the detailed log messages are NOT present
check_output_does_not_contain "$M7A_T3_OUTPUT" "Comparing source and destination items" "Test 3 No Log Msg 1"
check_output_does_not_contain "$M7A_T3_OUTPUT" "Scheduling copy/create (new): file1.txt" "Test 3 No Log Msg 2"
check_output_does_not_contain "$M7A_T3_OUTPUT" "Executing CopyFile actions" "Test 3 No Log Msg 3"
check_output_does_not_contain "$M7A_T3_OUTPUT" "Copying file: file1.txt to" "Test 3 No Log Msg 4"
check_output_does_not_contain "$M7A_T3_OUTPUT" "Synchronization actions finished." "Test 3 No Log Msg 5"
# Check for the minimal output expected in non-test mode (from Program.cs)
check_output_contains "$M7A_T3_OUTPUT" "Starting FileSync..." "Test 3 Minimal Output Start"
check_output_contains "$M7A_T3_OUTPUT" "FileSync finished." "Test 3 Minimal Output End"
echo "--- Test 3 PASSED ---" | tee -a "$LOG_FILE"


# --- Cleanup ---
cleanup

echo "
===== Milestone 7a Verification PASSED =====" | tee -a "$LOG_FILE"
exit 0 