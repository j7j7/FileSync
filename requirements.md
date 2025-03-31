# FileSync Application Requirements

This document outlines the requirements for the FileSync application.

## 1. Core Functionality

-   The application will synchronize files and folders from a specified source directory to a specified destination directory.
-   Source and destination paths will be provided as command-line arguments.
-   Synchronization will be one-way: changes from the source will be reflected in the destination.

## 2. Platform Support

-   The application must run natively on:
    -   Windows
    -   macOS
    -   Linux
-   Separate build artifacts may be generated for each platform if necessary, but the core codebase should be platform-agnostic where possible.

## 3. Performance

-   Synchronization should be fast and efficient, minimizing resource usage (CPU, memory, I/O).
-   **Initial directory scanning** to identify files and folders for comparison should rely solely on **metadata** (names, timestamps, file attributes) and **avoid reading file content**.
-   The application should utilize **multithreading** to parallelize file analysis and copying operations where beneficial.
    -   An optional command-line argument (e.g., `--threads <N>`) should allow the user to specify the number of worker threads to use. If not specified, a sensible default based on system resources should be used.
-   Optimize file I/O operations.

## 4. User Interface (Command Line)

-   The application will run as a command-line tool.
-   During synchronization, a **single-line, real-time status** display must be shown in the terminal, including:
    -   The current file or folder being processed.
    -   A progress indicator (e.g., percentage or progress bar).
    -   The number of items processed / total items.
    -   Estimated time remaining.
    -   Elapsed time.

## 5. Technology

-   The application will be developed using **C#** and a modern .NET version (e.g., .NET 8 or later) to leverage cross-platform capabilities and performance improvements.

## 6. Code Structure & Quality

-   The codebase must be **modular**, promoting reusability and maintainability.
-   Avoid duplication of functions or logic.
-   Adhere to standard C# coding conventions and best practices.
-   Include basic error handling and logging.

## 7. Synchronization Logic

-   The process starts with an efficient scan of both source and destination directories to gather file/folder metadata (name, path, timestamp, size, attributes) without reading file content.
-   Based on the selected mode (`--update` or `--oneway`) and the collected metadata, the application determines the necessary actions (copy, delete, skip).
-   The application supports two main synchronization modes, specified via command-line arguments:
    -   **`--update` (Default Mode):**
        -   Copies files from the source to the destination if the file does not exist in the destination or if the source file's **last modified timestamp** is **newer** than the destination file's timestamp.
        -   Files/directories existing only in the destination are **left untouched**.
    -   **`--oneway`:**
        -   Makes the destination directory an exact mirror of the source directory.
        -   Copies new/newer files from source to destination (same timestamp logic as `--update`).
        -   **Deletes** files and directories from the destination if they **do not exist** in the source. This ensures the destination perfectly reflects the source.
-   If neither `--update` nor `--oneway` is specified, the application should default to `--update` behavior.
-   Directory structure from the source will be replicated in the destination as needed.

## 8. Cloud Storage Compatibility

-   The application must correctly handle files stored in cloud storage services (e.g., Microsoft OneDrive, Dropbox) that use **stub files** (placeholders for online-only files).
-   The application needs to interact with the underlying system mechanisms (like Windows Cloud Files API, macOS File Provider) or potentially specific cloud provider SDKs to:
    -   Identify if a file is a stub.
    -   Avoid unnecessary downloads if only metadata (like timestamps) is needed and available.

## 9. Build & Deployment

-   Provide clear instructions for building the application on each target platform.
-   Consider packaging options for easier distribution (e.g., installers, self-contained executables). 