#!/bin/bash

# Verification Script for Milestone 6: Multithreading Implementation (Correctness)

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
PROJECT_DIR="src/FileSync.App"
APP_NAME="FileSync.App"
TEST_SRC_DIR="m6_test_src"
TEST_DEST_DIR="m6_test_dest"
LOG_FILE="milestone6_verification.log"
NUM_FILES=50 # Number of test files to create

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
    # Use time command for rough performance indication (optional)
    # time dotnet run --project "$PROJECT_DIR/$APP_NAME.csproj" -- "$@" > "$tmp_out" 2> "$tmp_err"
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

check_output_contains() {
    local output="$1"
    local expected_text="$2"
    local description="$3"

    echo -n "VERIFY: $description - Output contains '$expected_text' ... " | tee -a "$LOG_FILE"
    if echo "$output" | grep -qF -- "$expected_text"; then echo "PASSED" | tee -a "$LOG_FILE"; else echo "FAILED" | tee -a "$LOG_FILE"; echo "Output was:"; echo "$output" | tee -a "$LOG_FILE"; exit 1; fi
}

check_file_exists() {
    local file_path="$1"; local description="$2"
    echo -n "VERIFY: $description - Existence [$file_path] ... " | tee -a "$LOG_FILE"
    if [[ -e "$file_path" ]]; then echo "PASSED" | tee -a "$LOG_FILE"; else echo "FAILED" | tee -a "$LOG_FILE"; exit 1; fi
}

check_files_match() {
    local file1_path="$1"; local file2_path="$2"; local description="$3"
    echo -n "VERIFY: $description - Content Match [$file1_path vs $file2_path] ... " | tee -a "$LOG_FILE"
    if cmp -s "$file1_path" "$file2_path"; then echo "PASSED" | tee -a "$LOG_FILE"; else echo "FAILED" | tee -a "$LOG_FILE"; exit 1; fi
}

# --- Test Setup Function ---
setup_test_files() {
    local num_files=$1
    echo "INFO: Creating $num_files test files in source..." | tee -a "$LOG_FILE"
    mkdir -p "$TEST_SRC_DIR/subdir"
    mkdir -p "$TEST_DEST_DIR" # Keep dest empty initially

    for i in $(seq 1 $num_files); do
        # Create files with slightly varying content
        echo "Source Content for file $i" > "$TEST_SRC_DIR/file_$i.txt"
        if (( i % 5 == 0 )); then # Put some in subdir
             echo "Source Content for sub file $i" > "$TEST_SRC_DIR/subdir/subfile_$i.txt"
        fi
    done
    echo "INFO: Test setup complete." | tee -a "$LOG_FILE"
}

# --- Verification Function ---
verify_destination_state() {
    local num_files=$1
    local test_label="$2"
    echo "INFO: Verifying destination directory state ($test_label)..." | tee -a "$LOG_FILE"
    local failed=0
    for i in $(seq 1 $num_files); do
        local src_file="$TEST_SRC_DIR/file_$i.txt"
        local dest_file="$TEST_DEST_DIR/file_$i.txt"
        if [[ -e "$src_file" ]]; then
             check_file_exists "$dest_file" "File $i exists ($test_label)"
             check_files_match "$src_file" "$dest_file" "File $i content ($test_label)"
        fi

        if (( i % 5 == 0 )); then # Check sub files
             local src_subfile="$TEST_SRC_DIR/subdir/subfile_$i.txt"
             local dest_subfile="$TEST_DEST_DIR/subdir/subfile_$i.txt"
             if [[ -e "$src_subfile" ]]; then
                  check_file_exists "$dest_subfile" "Subfile $i exists ($test_label)"
                  check_files_match "$src_subfile" "$dest_subfile" "Subfile $i content ($test_label)"
             fi
        fi
    done
    check_file_exists "$TEST_DEST_DIR/subdir" "Subdirectory exists ($test_label)"
    echo "INFO: Destination state verification successful ($test_label)." | tee -a "$LOG_FILE"
}


# --- Main Script ---
echo "===== Starting Milestone 6 Verification (Correctness) =====" | tee "$LOG_FILE"

DEFAULT_THREADS=$(getconf _NPROCESSORS_ONLN || getconf NPROCESSORS_ONLN || echo 1)
echo "INFO: Detected default processor count: $DEFAULT_THREADS" | tee -a "$LOG_FILE"

# --- Test 1: Default Threads ---
echo "
--- Test 1: Running with default threads ---
" | tee -a "$LOG_FILE"
cleanup && setup_test_files $NUM_FILES
run_app M6_T1_EXIT M6_T1_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --oneway
if [[ "$M6_T1_EXIT" -ne 0 ]]; then echo "TEST 1 FAILED (Exit Code: $M6_T1_EXIT)"; cleanup; exit 1; fi
check_output_contains "$M6_T1_OUTPUT" "Threads: $DEFAULT_THREADS" "Test 1 Default Threads Correctness"
verify_destination_state $NUM_FILES "Test 1 (Default Threads)"
echo "--- Test 1 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 2: Single Thread ---
echo "
--- Test 2: Running with --threads 1 ---
" | tee -a "$LOG_FILE"
cleanup && setup_test_files $NUM_FILES
run_app M6_T2_EXIT M6_T2_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --oneway --threads 1
if [[ "$M6_T2_EXIT" -ne 0 ]]; then echo "TEST 2 FAILED (Exit Code: $M6_T2_EXIT)"; cleanup; exit 1; fi
check_output_contains "$M6_T2_OUTPUT" "Threads: 1" "Test 2 Single Thread Correctness"
verify_destination_state $NUM_FILES "Test 2 (--threads 1)"
echo "--- Test 2 PASSED ---" | tee -a "$LOG_FILE"

# --- Test 3: Multiple Threads ---
THREAD_COUNT_TEST=4 # Test with 4 threads
echo "
--- Test 3: Running with --threads $THREAD_COUNT_TEST ---
" | tee -a "$LOG_FILE"
cleanup && setup_test_files $NUM_FILES
run_app M6_T3_EXIT M6_T3_OUTPUT "$TEST_SRC_DIR" "$TEST_DEST_DIR" --oneway --threads $THREAD_COUNT_TEST
if [[ "$M6_T3_EXIT" -ne 0 ]]; then echo "TEST 3 FAILED (Exit Code: $M6_T3_EXIT)"; cleanup; exit 1; fi
check_output_contains "$M6_T3_OUTPUT" "Threads: $THREAD_COUNT_TEST" "Test 3 Multi Thread Correctness"
verify_destination_state $NUM_FILES "Test 3 (--threads $THREAD_COUNT_TEST)"
echo "--- Test 3 PASSED ---" | tee -a "$LOG_FILE"


# --- Cleanup ---
cleanup

echo "
===== Milestone 6 Verification PASSED =====" | tee -a "$LOG_FILE"
exit 0 