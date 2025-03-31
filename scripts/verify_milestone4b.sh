#!/bin/bash

# Verification Script for Milestone 4b: --oneway Option Parsing

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
PROJECT_DIR="src/FileSync.App"
APP_NAME="FileSync.App"
TEST_SRC_DIR="m4b_test_src"
TEST_DEST_DIR="m4b_test_dest"
LOG_FILE="milestone4b_verification.log"

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
    local output="$1"
    local expected_text="$2"
    local description="$3"

    echo -n "VERIFY: $description - Output contains '$expected_text' ... " | tee -a "$LOG_FILE"
    # Use grep -qF for quiet, fixed string matching
    if echo "$output" | grep -qF -- "$expected_text"; then
        echo "PASSED" | tee -a "$LOG_FILE"
    else
        echo "FAILED" | tee -a "$LOG_FILE"
        echo "Output was:" >> "$LOG_FILE"
        echo "$output" >> "$LOG_FILE"
        exit 1
    fi
}

check_exit_code() {
    local actual_code="$1"
    local expected_code="$2"
    local description="$3"

    echo -n "VERIFY: $description - Exit code [$actual_code vs $expected_code] ... " | tee -a "$LOG_FILE"
    if [[ "$actual_code" -eq "$expected_code" ]]; then
        echo "PASSED" | tee -a "$LOG_FILE"
    else
        echo "FAILED (Expected $expected_code)" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# --- Main Script ---
echo "===== Starting Milestone 4b Verification =====" | tee "$LOG_FILE"
cleanup # Clean start

# Setup minimal dirs just so path validation passes
mkdir -p "$TEST_SRC_DIR"
mkdir -p "$TEST_DEST_DIR"

# --- Test 1: Check --help Output ---
echo "
--- Test 1: Checking --help output ---
" | tee -a "$LOG_FILE"
run_app M4B_T1_EXIT M4B_T1_OUTPUT --help
check_exit_code "$M4B_T1_EXIT" 0 "Test 1 Help Exit Code"
check_output_contains "$M4B_T1_OUTPUT" "--oneway" "Test 1 Help Output"
echo "--- Test 1 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 2: Run with --oneway (parsing only) ---
echo "
--- Test 2: Running with --oneway ---
" | tee -a "$LOG_FILE"
# Add a dummy file so SyncEngine gets called
touch "$TEST_SRC_DIR/dummy.txt"
run_app M4B_T2_EXIT M4B_T2_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --oneway
# Should run successfully (exit 0) even if logic isn't implemented
check_exit_code "$M4B_T2_EXIT" 0 "Test 2 OneWay Exit Code"
# Should report using OneWay mode
check_output_contains "$M4B_T2_OUTPUT" "Sync Mode: OneWay" "Test 2 OneWay Mode Selection"
# Should show the warning about logic not implemented
check_output_contains "$M4B_T2_OUTPUT" "Warning: OneWay mode logic not yet fully implemented" "Test 2 OneWay Warning"
echo "--- Test 2 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 3: Run with --update and --oneway (should fail parsing) ---
echo "
--- Test 3: Running with --update AND --oneway ---
" | tee -a "$LOG_FILE"
run_app M4B_T3_EXIT M4B_T3_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --update --oneway
# Should fail with a non-zero exit code (typically 1 for parsing errors)
check_exit_code "$M4B_T3_EXIT" 1 "Test 3 Mutual Exclusion Exit Code"
# Should contain the validator's error message
check_output_contains "$M4B_T3_OUTPUT" "Options --update and --oneway cannot be used together" "Test 3 Mutual Exclusion Error Msg"
echo "--- Test 3 PASSED ---" | tee -a "$LOG_FILE"


# --- Cleanup ---
cleanup

echo "
===== Milestone 4b Verification PASSED =====" | tee -a "$LOG_FILE"
exit 0