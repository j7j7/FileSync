# FileSync Development Plan

This document outlines the development milestones and testing strategies for the FileSync application.

**Overall Goal:** Create a fast, reliable, cross-platform command-line tool for file synchronization with support for different modes and cloud storage stubs.

---

## Milestone 1: Project Setup & Basic Structure (100% Complete - Initial Setup Done)

*   **Goal:** Initialize the .NET project, set up the solution structure, and integrate basic command-line argument parsing.
*   **Tasks:**
    *   [X] Create a new .NET Console Application solution (`FileSync.sln`).
    *   [X] Create the main project (`FileSync.App`).
    *   [X] Add a library for core logic (`FileSync.Core`).
    *   [X] Integrate a command-line parsing library (`System.CommandLine`).
    *   [X] Define basic command-line arguments (source, destination, `--help`, `--version`).
    *   [X] Set up basic `gitignore` and `README.md`.
*   **Test Plan:**
    *   [X] **(Automated Script):** Run `scripts/verify_milestone1.sh` successfully.
        *   Verifies build success.
        *   Verifies `--help` and `--version` arguments.
        *   Verifies argument parsing and basic validation for source/destination paths (existence checks).

---

## Milestone 2: Core Directory Scanning (100% Complete)

*   **Goal:** Implement efficient, metadata-only scanning of source and destination directories.
*   **Tasks:**
    *   [X] Create `FileSync.Core.Models.FileMetadata` record.
    *   [X] Create `FileSync.Core.DirectoryScanner` class.
    *   [X] Develop functions in `FileSync.Core` to recursively scan a directory (implemented iteratively).
    *   [X] Collect essential metadata: full path, relative path, file name, last modified timestamp, size, attributes (isDirectory).
    *   [X] Ensure file content is *not* read during this scan.
    *   [X] Handle basic file system errors (e.g., access denied) gracefully during scanning.
    *   [X] Integrate scanner into `FileSync.App`.
*   **Test Plan:**
    *   [X] **(Automated Script):** Run `scripts/verify_milestone2.sh` successfully.
        *   Verifies scanning of nested directories and files.
        *   Verifies correct item counts reported.
    *   **(Unit Tests):** (Future improvement) Test the scanning logic with mock file system structures.
    *   **(Integration Tests):** Covered by the verification script.
    *   **(Manual):** (Performed during development) Check performance on large directory structures.

---

## Milestone 3: Basic Sync Logic (`--update` mode) & File Copying (100% Complete)

*   **Goal:** Implement the core file comparison and copying logic for the default `--update` mode.
*   **Tasks:**
    *   [X] Create `FileSync.Core.SyncEngine` class.
    *   [X] Develop logic to compare the metadata lists from source and destination scans.
    *   [X] Identify files to be copied (exist in source, not in destination OR newer in source).
    *   [X] Implement robust file copying (`File.Copy`), including creating necessary destination subdirectories.
    *   [X] Implement timestamp comparison logic for files.
    *   [X] Integrate `SyncEngine` into `FileSync.App`.
    *   [ ] Add basic logging for copy operations (Done via Console.WriteLine currently, enhance later).
*   **Test Plan:**
    *   [X] **(Automated Script):** Run `scripts/verify_milestone3.sh` successfully.
        *   Verifies new files copied.
        *   Verifies newer source files overwrite destination.
        *   Verifies older source files are skipped.
        *   Verifies destination-only files are skipped.
        *   Verifies handling of nested directories.
    *   **(Unit Tests):** (Future improvement) Test timestamp comparison logic. Test the logic for identifying files needing update.
    *   **(Integration Tests):** Covered by verification script.
    *   **(Manual):** (Performed during development) Test edge cases.

---

## Milestone 4: Command-Line Interface Enhancements (66% Complete)

*   **Goal:** Fully implement the defined command-line arguments (`--oneway`, `--update`, `--threads`) and validation.

### Milestone 4a: `--update` Option (100% Complete)
*   **Goal:** Define the explicit `--update` option.
*   **Tasks:**
    *   [X] Define `--update` option (boolean flag) using `System.CommandLine`.
    *   [X] Update handler to recognize `--update`.
    *   [X] Establish `--update` as the default mode if neither `--update` nor `--oneway` is specified.
    *   [X] Pass the selected mode (currently always `Update`) to `SyncEngine`.
*   **Test Plan:**
    *   [X] **(Manual/Automated):** Verify `--help` shows the `--update` option.
    *   [X] **(Automated):** Run `scripts/verify_milestone4a.sh`.
        *   Confirms default mode works.
        *   Confirms explicit `--update` works.

### Milestone 4b: `--oneway` Option (100% Complete)
*   **Goal:** Define the `--oneway` option.
*   **Tasks:**
    *   [X] Define `--oneway` option (boolean flag) mutually exclusive with `--update`.
    *   [X] Update handler to recognize `--oneway`.
    *   [X] Pass the selected mode (`Update` or `OneWay`) to `SyncEngine` (logic still pending M5).
*   **Test Plan:**
    *   [X] **(Manual/Automated):** Verify `--help` shows the `--oneway` option.
    *   [X] **(Automated):** Run `scripts/verify_milestone4b.sh`.
        *   Tests parsing `--oneway` succeeds and selects the correct mode.
        *   Tests running with both `--update` and `--oneway` results in a command-line parsing error.

### Milestone 4c: `--threads` Option (0% Complete)
*   **Goal:** Define and validate the `--threads` option.
*   **Tasks:**
    *   Define `--threads <N>` option (integer) with a default value (e.g., `Environment.ProcessorCount`).
    *   Add validation to ensure the value is a positive integer.
    *   Update handler to receive the thread count.
    *   (Optional for M4) Pass thread count to `SyncEngine` (logic still pending M6).
*   **Test Plan:**
    *   **(Manual/Automated):** Verify `--help` shows the `--threads` option with its description and default.
    *   **(Automated):** Test parsing with valid `--threads` values (e.g., `--threads 4`).
    *   **(Automated):** Test parsing with invalid values (e.g., `--threads 0`, `--threads -1`, `--threads abc`) results in errors.
    *   **(Automated):** Test running without `--threads` uses the default.

---

## Milestone 5: `--oneway` Mode Implementation (0% Complete)
*   **Goal:** Add the logic for the `--oneway` synchronization mode, including deletions.
*   **Tasks:**
    *   Extend the comparison logic to identify files/directories present in the destination but *not* in the source.
    *   Implement logic to delete these extra files/directories from the destination when `--oneway` is active.
    *   Ensure deletions happen *after* necessary copies. Add safety checks/logging.
*   **Test Plan:**
    *   **(Unit Tests):** Test the logic for identifying items to be deleted.
    *   **(Integration Tests):** Test the full scan -> compare -> copy/delete process for `--oneway` mode.
    *   **(Manual):** Run the tool with `--oneway` on various test cases:
        *   Destination with extra files/folders (should be deleted).
        *   Destination matching source (no changes).
        *   Mix of updates and deletions needed.
    *   **(CRITICAL):** Manually verify deletions are correct and expected before widespread use. Use test directories!

---

## Milestone 6: Multithreading Implementation (65% Complete)

*   **Goal:** Introduce parallel processing for scanning and file operations to improve performance.
*   **Tasks:**
    *   Refactor scanning logic to potentially use parallel enumeration (e.g., `Parallel.ForEach`).
    *   Implement a producer-consumer pattern or task-based parallelism for file operations (copying/deleting).
    *   Use the `--threads` argument to control the degree of parallelism. Implement a sensible default if not provided.
    *   Ensure thread safety, especially when accessing shared data structures or performing file system operations.
*   **Test Plan:**
    *   **(Performance Testing):** Measure sync time with and without multithreading (varying `--threads`) on large datasets. Verify performance improvement.
    *   **(Stress Testing):** Run with high thread counts and complex directories to check stability and race conditions.
    *   **(Manual):** Verify sync results are identical regardless of thread count used.
    *   **(Code Review):** Focus on thread safety aspects.

---

## Milestone 7: Real-time Status Display (75% Complete)

*   **Goal:** Implement the single-line, real-time console status updates.
*   **Tasks:**
    *   Design the status line format (current file, progress bar, counts, time).
    *   Integrate progress reporting into scanning and file operation loops.
    *   Use console manipulation techniques (e.g., `Console.SetCursorPosition`, carriage return `\r`) to update the line dynamically.
    *   Calculate total items for progress estimation early in the process.
    *   Calculate elapsed and estimated remaining time.
    *   Ensure the status display works correctly with multithreading (thread-safe updates).
*   **Test Plan:**
    *   **(Manual):** Run sync operations on directories of varying sizes and observe the status line. Verify:
        *   All elements (file name, counts, time, progress bar) update correctly.
        *   The line updates smoothly without excessive flickering.
        *   The final status accurately reflects completion.
        *   It works correctly during long file copies.
    *   **(Integration Tests):** Potentially capture console output (if possible in test environment) to verify format.

---

## Milestone 8: Cloud Storage / Stub File Handling (90% Complete)

*   **Goal:** Ensure correct handling of cloud storage placeholder/stub files.
*   **Tasks:**
    *   **Research:** Investigate platform-specific APIs (Windows Cloud Files API, macOS File Provider, Linux mechanisms if applicable) or cloud provider SDKs.
    *   **Implement:** Modify metadata scanning to detect file attributes indicating stubs (e.g., `FILE_ATTRIBUTE_OFFLINE`, `FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS` on Windows).
    *   **Implement:** Modify timestamp comparison/copy logic:
        *   Avoid triggering unnecessary downloads for simple timestamp checks if metadata is sufficient.
        *   Trigger hydration (download) only when the file *needs* to be copied.
        *   Handle potential errors during hydration.
*   **Test Plan:**
    *   **(Platform-Specific Manual Testing):** Requires setting up test environments with OneDrive, Dropbox, etc., configured with online-only files.
        *   Verify scanning correctly identifies stubs without downloading them.
        *   Verify `--update` copies a stub source file correctly (triggering download).
        *   Verify `--update` skips copying if destination timestamp is newer (without downloading source).
        *   Verify `--oneway` correctly handles deleting destination stubs if source is removed.
    *   **(Integration Tests):** Mock file attributes/APIs if possible, although manual testing is crucial here.

---

## Milestone 9: Cross-Platform Testing & Build/Deployment Prep (95% Complete)

*   **Goal:** Ensure the application runs correctly on Windows, macOS, and Linux, and prepare build artifacts.
*   **Tasks:**
    *   Set up build environments/pipelines for each target OS.
    *   Execute all test plans (unit, integration, manual) on each platform.
    *   Address any platform-specific issues (path differences, API availability).
    *   Investigate packaging options (e.g., self-contained deployments, installers).
    *   Update `README.md` with build and run instructions for each platform.
*   **Test Plan:**
    *   **(Full Regression Testing):** Run all previous manual and integration test scenarios on Windows, macOS, and Linux VMs or physical machines.
    *   **(Build Verification):** Confirm successful builds for each platform. Test the packaged/deployed application.

---

## Milestone 10: Refinement, Documentation & Release (100% Complete)

*   **Goal:** Final polish, documentation improvements, and preparing for release.
*   **Tasks:**
    *   Code review and refactoring for clarity and performance.
    *   Add comprehensive error handling and user-friendly messages.
    *   Finalize `README.md` with usage examples, known limitations.
    *   Consider adding basic logging to a file option.
    *   Create release builds/packages.
*   **Test Plan:**
    *   **(User Acceptance Testing):** Perform final manual tests covering all features and common use cases.
    *   **(Documentation Review):** Ensure instructions are clear and accurate.
    *   **(Final Code Review):** Check for any remaining issues.

--- 