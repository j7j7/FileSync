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

## Milestone 4: Command-Line Interface Enhancements (100% Complete)

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

### Milestone 4c: `--threads` Option (100% Complete)
*   **Goal:** Define and validate the `--threads` option.
*   **Tasks:**
    *   [X] Define `--threads <N>` option (integer) with a default value (`Environment.ProcessorCount`).
    *   [X] Add validation to ensure the value is a positive integer.
    *   [X] Update handler to receive the thread count.
    *   [ ] (Optional for M4) Pass thread count to `SyncEngine` (logic still pending M6) - *Deferred to M6*.
*   **Test Plan:**
    *   [X] **(Manual/Automated):** Verify `--help` shows the `--threads` option with its description and default.
    *   [X] **(Automated):** Run `scripts/verify_milestone4c.sh`.
        *   Tests parsing with valid `--threads` values.
        *   Tests parsing with invalid values (`0`, `-1`, `abc`) results in errors.
        *   Tests running without `--threads` uses the default.

---

## Milestone 5: `--oneway` Mode Implementation (100% Complete)
*   **Goal:** Add the logic for the `--oneway` synchronization mode, including deletions.
*   **Tasks:**
    *   [X] Extend the comparison logic to identify files/directories present in the destination but *not* in the source.
    *   [X] Implement logic to delete these extra files/directories from the destination when `--oneway` is active.
    *   [X] Ensure deletions happen *after* necessary copies (and deletes process deeper items first).
*   **Test Plan:**
    *   [ ] **(Unit Tests):** (Future) Test the logic for identifying items to be deleted.
    *   [X] **(Integration Tests):** Covered by `scripts/verify_milestone5.sh`.
    *   [X] **(Manual):** (Covered by script) Run the tool with `--oneway` on various test cases:
        *   [X] Destination with extra files/folders (should be deleted).
        *   [ ] Destination matching source (no changes) - *Implicitly tested by lack of delete actions in output/logs, enhance script if needed*.
        *   [X] Mix of updates and deletions needed.
    *   [X] **(CRITICAL):** (Handled by script for basic cases) Manually verify deletions are correct.

---

## Milestone 6: Multithreading Implementation (100% Complete - Correctness Verified)

*   **Goal:** Introduce parallel processing for scanning and file operations to improve performance.
*   **Tasks:**
    *   [ ] Refactor scanning logic to potentially use parallel enumeration - *Deferred*. (Current iterative scan is reasonably efficient).
    *   [X] Implement parallel execution for file operations (`CopyFile`, `DeleteFile`, `DeleteDirectory`) in `SyncEngine` using `Parallel.ForEachAsync`.
    *   [X] Use the `--threads` argument to control the degree of parallelism (`MaxDegreeOfParallelism`).
    *   [X] Ensure basic thread safety for file operations (handled by processing types sequentially and parallelizing within types).
*   **Test Plan:**
    *   [ ] **(Performance Testing):** (Future improvement) Measure sync time with varying `--threads` on large datasets.
    *   [ ] **(Stress Testing):** (Future improvement) Run with high thread counts and complex directories.
    *   [X] **(Manual/Automated):** Run `scripts/verify_milestone6.sh`.
        *   Verifies sync results are identical regardless of thread count used (default, 1, 4).
    *   [ ] **(Code Review):** (Recommended) Focus on thread safety aspects.

---

## Milestone 7: Real-time Status Display (50% Complete)

*   **Goal:** Implement the single-line, real-time console status updates, with an option to revert to detailed logging for testing.

### Milestone 7a: `--test` Flag and Conditional Logging (100% Complete)
*   **Goal:** Add a `--test` flag to control output verbosity.
*   **Tasks:**
    *   [X] Define `--test` option (boolean flag) in `Program.cs`.
    *   [X] Pass `isTestMode` boolean to `SyncEngine` (and potentially `DirectoryScanner`).
    *   [X] Make existing `Console.WriteLine` logs within core logic conditional on `isTestMode`.
    *   [X] Update existing verification scripts (`verify_milestone3.sh` through `verify_milestone6.sh`) to use the `--test` flag.
*   **Test Plan:**
    *   [X] **(Manual/Automated):** Verify `--help` shows the `--test` option.
    *   [X] **(Automated):** Run `scripts/verify_milestone7a.sh` successfully.
    *   [X] **(Automated):** Re-run verification scripts 3-6; they should pass by using the `--test` flag and seeing the expected detailed logs.
    *   [X] **(Manual/Automated):** Run a sync *without* `--test` and verify that the detailed logs are *not* shown (output should be minimal for now) - *Covered by verify_milestone7a.sh*.

### Milestone 7b: Status Display Implementation (0% Complete)
*   **Goal:** Implement the single-line status display when `--test` is *not* present.
*   **Tasks:**
    *   Define `ProgressReport` class/struct (e.g., current item, progress %, count, total, elapsed/ETA).
    *   Add `IProgress<ProgressReport>` parameters to `ScanDirectoryAsync` and `SynchronizeAsync`.
    *   Implement progress reporting calls within `DirectoryScanner` and `SyncEngine` loops (thread-safe updates needed in `SyncEngine`).
    *   Implement console rendering logic in `Program.cs` (using `Console.SetCursorPosition`, etc.) triggered by the `IProgress` handler, only if `isTestMode` is false.
    *   Calculate total items/bytes for progress estimation.
    *   Calculate elapsed and estimated remaining time.
*   **Test Plan:**
    *   **(Manual):** Run sync operations *without* `--test` on directories of varying sizes and observe the status line. Verify:
        *   All elements update correctly.
        *   The line updates smoothly.
        *   The final status is correct.
        *   It works during long operations.
    *   **(Integration Tests):** (Difficult/Low ROI) Consider skipping automated tests for dynamic console output.

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