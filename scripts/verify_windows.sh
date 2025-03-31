#!/bin/bash

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FileSync.App"
TEST_SRC_DIR="$PROJECT_DIR/temp_src"
TEST_DEST_DIR="$PROJECT_DIR/temp_dest"
LOG_FILE="$PROJECT_DIR/verify_windows.log"

# Helper functions
cleanup() {
    echo "Cleaning up test directories..."
    rm -rf "$TEST_SRC_DIR" "$TEST_DEST_DIR"
}

run_app() {
    dotnet run --project "$PROJECT_DIR/src/$APP_NAME/$APP_NAME.csproj" -- "$@"
}

check_output() {
    local output="$1"
    local expected="$2"
    if echo "$output" | grep -q "$expected"; then
        return 0
    else
        echo "❌ Expected output not found: $expected"
        return 1
    fi
}

check_not_output() {
    local output="$1"
    local unexpected="$2"
    if echo "$output" | grep -q "$unexpected"; then
        echo "❌ Unexpected output found: $unexpected"
        return 1
    else
        return 0
    fi
}

# Main script
echo "Starting Windows-specific verification..." > "$LOG_FILE"

# Test 1: Path handling with different separators
echo "Test 1: Path handling with different separators" >> "$LOG_FILE"
cleanup
mkdir -p "$TEST_SRC_DIR/test\path/with\mixed/separators"
touch "$TEST_SRC_DIR/test\path/with\mixed/separators/test.txt"
run_app "$TEST_SRC_DIR" "$TEST_DEST_DIR" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Test 1 passed: Path handling with mixed separators"
else
    echo "❌ Test 1 failed: Path handling with mixed separators"
    exit 1
fi

# Test 2: Long path handling
echo "Test 2: Long path handling" >> "$LOG_FILE"
cleanup
mkdir -p "$TEST_SRC_DIR/$(printf 'a%.0s' {1..200})/$(printf 'b%.0s' {1..200})"
touch "$TEST_SRC_DIR/$(printf 'a%.0s' {1..200})/$(printf 'b%.0s' {1..200})/test.txt"
run_app "$TEST_SRC_DIR" "$TEST_DEST_DIR" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Test 2 passed: Long path handling"
else
    echo "❌ Test 2 failed: Long path handling"
    exit 1
fi

# Test 3: Special characters in filenames
echo "Test 3: Special characters in filenames" >> "$LOG_FILE"
cleanup
mkdir -p "$TEST_SRC_DIR"
touch "$TEST_SRC_DIR/file with spaces.txt"
touch "$TEST_SRC_DIR/file!@#$%^&*().txt"
touch "$TEST_SRC_DIR/file[{}]|.txt"
run_app "$TEST_SRC_DIR" "$TEST_DEST_DIR" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Test 3 passed: Special characters in filenames"
else
    echo "❌ Test 3 failed: Special characters in filenames"
    exit 1
fi

# Test 4: Read-only files
echo "Test 4: Read-only files" >> "$LOG_FILE"
cleanup
mkdir -p "$TEST_SRC_DIR"
touch "$TEST_SRC_DIR/readonly.txt"
chmod 444 "$TEST_SRC_DIR/readonly.txt"
run_app "$TEST_SRC_DIR" "$TEST_DEST_DIR" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Test 4 passed: Read-only files"
else
    echo "❌ Test 4 failed: Read-only files"
    exit 1
fi

# Test 5: Progress reporting
echo "Test 5: Progress reporting" >> "$LOG_FILE"
cleanup
mkdir -p "$TEST_SRC_DIR/$(printf 'dir%.0s' {1..100})"
for i in {1..100}; do
    touch "$TEST_SRC_DIR/dir$i/file$i.txt"
done
output=$(run_app "$TEST_SRC_DIR" "$TEST_DEST_DIR" 2>&1)
if echo "$output" | grep -q "Progress:"; then
    echo "✅ Test 5 passed: Progress reporting"
else
    echo "❌ Test 5 failed: Progress reporting"
    exit 1
fi

# Test 6: Hidden files and directories
echo "Test 6: Hidden files and directories" >> "$LOG_FILE"
cleanup
mkdir -p "$TEST_SRC_DIR/.hidden_dir"
touch "$TEST_SRC_DIR/.hidden_file"
touch "$TEST_SRC_DIR/.hidden_dir/file.txt"
run_app "$TEST_SRC_DIR" "$TEST_DEST_DIR" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Test 6 passed: Hidden files and directories"
else
    echo "❌ Test 6 failed: Hidden files and directories"
    exit 1
fi

# Final cleanup
cleanup

echo "✅ All Windows-specific tests passed!"
echo "✅ All Windows-specific tests passed!" >> "$LOG_FILE" 