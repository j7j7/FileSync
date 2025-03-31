#!/bin/bash

# Verification Script for Milestone 4c: --threads Option Parsing & Validation

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
PROJECT_DIR="src/FileSync.App"
APP_NAME="FileSync.App"
TEST_SRC_DIR="m4c_test_src"
TEST_DEST_DIR="m4c_test_dest"
LOG_FILE="milestone4c_verification.log"

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
    # Run command, redirect stdout and stderr, capture exit code
    # Allow non-zero exit codes for tests that expect failure
    set +e
    dotnet run --project "$PROJECT_DIR/$APP_NAME.csproj" -- "$@" > "$tmp_out" 2> "$tmp_err"
    local exit_status=$?
    set -e # Re-enable exit on error
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
    local output="$1"
    local expected_text="$2"
    local description="$3"

    echo -n "VERIFY: $description - Output contains '$expected_text' ... " | tee -a "$LOG_FILE"
    if echo "$output" | grep -qF -- "$expected_text"; then echo "PASSED" | tee -a "$LOG_FILE"; else echo "FAILED" | tee -a "$LOG_FILE"; echo "Output was:"; echo "$output" | tee -a "$LOG_FILE"; exit 1; fi
}

check_output_does_not_contain() {
    local output="$1"
    local unexpected_text="$2"
    local description="$3"

    echo -n "VERIFY: $description - Output does NOT contain '$unexpected_text' ... " | tee -a "$LOG_FILE"
    if echo "$output" | grep -qF -- "$unexpected_text"; then echo "FAILED" | tee -a "$LOG_FILE"; echo "Output was:"; echo "$output" | tee -a "$LOG_FILE"; exit 1; else echo "PASSED" | tee -a "$LOG_FILE"; fi
}

check_exit_code() {
    local actual_code="$1"
    local expected_code="$2"
    local description="$3"

    echo -n "VERIFY: $description - Exit code [$actual_code vs $expected_code] ... " | tee -a "$LOG_FILE"
    if [[ "$actual_code" -eq "$expected_code" ]]; then echo "PASSED" | tee -a "$LOG_FILE"; else echo "FAILED (Expected $expected_code)" | tee -a "$LOG_FILE"; exit 1; fi
}

# --- Main Script ---
echo "===== Starting Milestone 4c Verification =====" | tee "$LOG_FILE"
cleanup # Clean start

# Setup minimal dirs for path validation
mkdir -p "$TEST_SRC_DIR"
mkdir -p "$TEST_DEST_DIR"

# Get expected default thread count (useful for checking default)
DEFAULT_THREADS=$(dotnet run --project "$PROJECT_DIR/$APP_NAME.csproj" -- --version > /dev/null 2>&1; echo $?) # Get processor count indirectly for script
DEFAULT_THREADS=$(getconf _NPROCESSORS_ONLN || getconf NPROCESSORS_ONLN || echo 1) # More reliable way
echo "INFO: Detected default processor count: $DEFAULT_THREADS" | tee -a "$LOG_FILE"

# --- Test 1: Check --help Output ---
echo "
--- Test 1: Checking --help output ---
" | tee -a "$LOG_FILE"
run_app M4C_T1_EXIT M4C_T1_OUTPUT --help
check_exit_code "$M4C_T1_EXIT" 0 "Test 1 Help Exit Code"
check_output_contains "$M4C_T1_OUTPUT" "--threads" "Test 1 Help Output (Option Name)"
# Check if default value is mentioned in help (System.CommandLine usually does)
check_output_contains "$M4C_T1_OUTPUT" "default: $DEFAULT_THREADS" "Test 1 Help Output (Default Value)"
echo "--- Test 1 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 2: Run with default threads ---
echo "
--- Test 2: Running with default threads ---
" | tee -a "$LOG_FILE"
run_app M4C_T2_EXIT M4C_T2_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR"
check_exit_code "$M4C_T2_EXIT" 0 "Test 2 Default Threads Exit Code"
check_output_contains "$M4C_T2_OUTPUT" "Threads: $DEFAULT_THREADS" "Test 2 Default Threads Value Used"
echo "--- Test 2 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 3: Run with specific valid threads ---
echo "
--- Test 3: Running with --threads 4 ---
" | tee -a "$LOG_FILE"
run_app M4C_T3_EXIT M4C_T3_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --threads 4
check_exit_code "$M4C_T3_EXIT" 0 "Test 3 Specific Threads Exit Code"
check_output_contains "$M4C_T3_OUTPUT" "Threads: 4" "Test 3 Specific Threads Value Used"
echo "--- Test 3 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 4: Run with invalid threads (0) ---
echo "
--- Test 4: Running with --threads 0 ---
" | tee -a "$LOG_FILE"
run_app M4C_T4_EXIT M4C_T4_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --threads 0
check_exit_code "$M4C_T4_EXIT" 1 "Test 4 Invalid Threads (0) Exit Code"
check_output_contains "$M4C_T4_OUTPUT" "must be a positive integer" "Test 4 Invalid Threads (0) Error Msg"
check_output_does_not_contain "$M4C_T4_OUTPUT" "Scanning source directory" "Test 4 Invalid Threads (0) No Scan"
echo "--- Test 4 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 5: Run with invalid threads (-1) ---
echo "
--- Test 5: Running with --threads -1 ---
" | tee -a "$LOG_FILE"
run_app M4C_T5_EXIT M4C_T5_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --threads -1
check_exit_code "$M4C_T5_EXIT" 1 "Test 5 Invalid Threads (-1) Exit Code"
check_output_contains "$M4C_T5_OUTPUT" "must be a positive integer" "Test 5 Invalid Threads (-1) Error Msg"
check_output_does_not_contain "$M4C_T5_OUTPUT" "Scanning source directory" "Test 5 Invalid Threads (-1) No Scan"
echo "--- Test 5 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 6: Run with invalid threads (text) ---
echo "
--- Test 6: Running with --threads abc ---
" | tee -a "$LOG_FILE"
run_app M4C_T6_EXIT M4C_T6_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --threads abc
check_exit_code "$M4C_T6_EXIT" 1 "Test 6 Invalid Threads (abc) Exit Code"
check_output_contains "$M4C_T6_OUTPUT" "Cannot parse argument 'abc'" "Test 6 Invalid Threads (abc) Error Msg"
check_output_does_not_contain "$M4C_T6_OUTPUT" "Scanning source directory" "Test 6 Invalid Threads (abc) No Scan"
echo "--- Test 6 PASSED ---" | tee -a "$LOG_FILE"

# --- Cleanup ---
cleanup

echo "
===== Milestone 4c Verification PASSED =====" | tee -a "$LOG_FILE"
exit 0 