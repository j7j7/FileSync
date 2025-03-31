#!/bin/bash

# Verification Script for Milestone 1: Project Setup & Basic Structure

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
PROJECT_DIR="src/FileSync.App"
APP_NAME="FileSync.App"
TEST_SRC_DIR="temp_test_src"
TEST_DEST_DIR="temp_test_dest"
LOG_FILE="milestone1_verification.log"

# --- Helper Functions ---
cleanup() {
    echo "INFO: Cleaning up temporary directories..."
    rm -rf "$TEST_SRC_DIR" "$TEST_DEST_DIR" "$LOG_FILE"
}

run_app() {
    # Runs the app, captures output and exit code, allows checking both
    # Usage: run_app <return_code_var> <output_var> [arguments...]
    local __exit_code_var=$1
    local __output_var=$2
    shift 2
    # Use temporary files for capturing output and stderr
    local tmp_out=$(mktemp)
    local tmp_err=$(mktemp)
    # Execute command, redirect stdout and stderr, capture exit code
    if dotnet run --project "$PROJECT_DIR/$APP_NAME.csproj" -- "$@" > "$tmp_out" 2> "$tmp_err"; then
        eval $__exit_code_var=0
    else
        # Store the actual non-zero exit code
        local exit_status=$?
        eval $__exit_code_var=$exit_status
    fi
    # Combine stdout and stderr into the output variable using printf -v for safety
    local combined_output
    combined_output=$(cat "$tmp_out" "$tmp_err")
    printf -v "$__output_var" '%s' "$combined_output"
    # Clean up temporary files
    rm -f "$tmp_out" "$tmp_err"
}

check_result() {
    # Checks exit code and that output contains ALL specified texts
    # Usage: check_result <description> <expected_exit_code> <actual_exit_code> <output> <expected_text1> [expected_text2] ...
    local description="$1"
    local expected_code="$2"
    local actual_code="$3"
    local output="$4"
    shift 4 # Shift past the first four arguments
    local expected_texts=("$@") # Remaining args are expected texts

    echo -n "TEST: $description ... " | tee -a "$LOG_FILE"
    if [[ "$actual_code" -ne "$expected_code" ]]; then
        echo "FAILED (Exit Code: $actual_code, Expected: $expected_code)" | tee -a "$LOG_FILE"
        echo "Output:" | tee -a "$LOG_FILE"
        echo "$output" | tee -a "$LOG_FILE"
        exit 1 # Fail script
    fi

    # Check each expected text individually
    for text in "${expected_texts[@]}"; do
        if ! echo "$output" | grep -qF "$text"; then # Use -F for fixed string matching
            echo "FAILED (Output missing text: '$text')" | tee -a "$LOG_FILE"
            echo "Output:" | tee -a "$LOG_FILE"
            echo "$output" | tee -a "$LOG_FILE"
            exit 1 # Fail script
        fi
    done

    echo "PASSED" | tee -a "$LOG_FILE"
}

check_error_result() {
    # Checks for non-zero exit code and specific error text
    # Usage: check_error_result <description> <actual_exit_code> <output> <expected_error_text>
    local description="$1"
    local actual_code="$2"
    local output="$3"
    local expected_text="$4"

    echo -n "TEST: $description ... " | tee -a "$LOG_FILE"
    if [[ "$actual_code" -eq 0 ]]; then
        echo "FAILED (Exit Code: 0, Expected: non-zero)" | tee -a "$LOG_FILE"
        echo "Output:" | tee -a "$LOG_FILE"
        echo "$output" | tee -a "$LOG_FILE"
        exit 1 # Fail script
    fi
    if ! echo "$output" | grep -q "$expected_text"; then
        echo "FAILED (Output missing error: '$expected_text')" | tee -a "$LOG_FILE"
        echo "Output:" | tee -a "$LOG_FILE"
        echo "$output" | tee -a "$LOG_FILE"
        exit 1 # Fail script
    fi
    echo "PASSED" | tee -a "$LOG_FILE"
}


# --- Main Script ---
echo "===== Starting Milestone 1 Verification =====" | tee "$LOG_FILE"

# 1. Build Test
echo -n "TEST: Building solution ... " | tee -a "$LOG_FILE"
if dotnet build FileSync.sln --nologo /clp:NoSummary /v:q > build.log 2>&1; then
    echo "PASSED" | tee -a "$LOG_FILE"
    rm -f build.log # Clean up log if successful
else
    echo "FAILED" | tee -a "$LOG_FILE"
    cat build.log | tee -a "$LOG_FILE" # Show build errors
    rm -f build.log
    exit 1
fi

# 2. Help Argument Test
run_app exit_code output --help
# Check for multiple key strings in the help output
check_result "Run with --help" 0 "$exit_code" "$output" "Usage:" "<source>" "<destination>"

# 3. Version Argument Test
run_app exit_code output --version
check_result "Run with --version" 0 "$exit_code" "$output" "1.0.0" # Adjust if version changes

# 4. Path Argument Tests
echo "INFO: Setting up test directories..." | tee -a "$LOG_FILE"
mkdir -p "$TEST_SRC_DIR" "$TEST_DEST_DIR"

# 4a. Valid Paths
run_app exit_code output "$TEST_SRC_DIR" "$TEST_DEST_DIR"
check_result "Run with valid paths" 0 "$exit_code" "$output" "Sync logic will be implemented here."
# Check if full paths are mentioned (optional, but good sanity check)
if ! echo "$output" | grep -q "$TEST_SRC_DIR"; then
     echo "WARN: Output did not contain source dir name '$TEST_SRC_DIR'" | tee -a "$LOG_FILE"
fi
if ! echo "$output" | grep -q "$TEST_DEST_DIR"; then
     echo "WARN: Output did not contain dest dir name '$TEST_DEST_DIR'" | tee -a "$LOG_FILE"
fi


# 4b. Missing Source Path
run_app exit_code output "non_existent_source_m1" "$TEST_DEST_DIR"
check_error_result "Run with non-existent source" "$exit_code" "$output" "Error: Source directory not found"

# 4c. Missing Destination Path
run_app exit_code output "$TEST_SRC_DIR" "non_existent_dest_m1"
check_error_result "Run with non-existent destination" "$exit_code" "$output" "Error: Destination directory not found"

# 4d. Missing Both Arguments (Should be handled by System.CommandLine)
run_app exit_code output
# System.CommandLine often returns 1 for parsing errors like missing arguments
check_error_result "Run with no arguments" "$exit_code" "$output" "Required argument missing for command: 'FileSync.App'"


# --- Cleanup ---
cleanup

echo "===== Milestone 1 Verification PASSED =====" | tee -a "$LOG_FILE"
exit 0 