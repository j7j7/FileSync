# Project Memory: FileSync Application

## Overview

A command-line file synchronization tool built with C#.

## Core Requirements

*   Sync files/folders from a source to a destination directory.
*   Supports two modes:
    *   `--update` (default): Copies new/newer files to destination, leaves extra destination files.
    *   `--oneway`: Mirrors source to destination, deleting extra destination files.
*   Command-line interface with source/destination path arguments and mode/thread options.
*   Optional `--threads <N>` argument for multithreading control.
*   Cross-platform support: Windows, macOS, Linux.
*   High performance and efficiency (utilizing multithreading).
    *   Initial directory scanning must use only metadata (no file content reading).
*   Real-time, single-line text status display during sync (progress, counts, time).
*   Synchronization based on newer source file timestamps.
*   Handles cloud storage stub files (e.g., OneDrive, Dropbox).

## Technology Stack

*   Language: C# (.NET 7 used initially, can update to 8+ later)
*   Command-line Parsing: `System.CommandLine` (pre-release)

## Core Components

*   **`FileSync.Core.SyncMode`**: Enum defining sync strategies (`Update`, `OneWay`).
*   **`FileSync.Core.Models.FileMetadata`**: Record holding file/directory info (Path, Name, Size, Timestamp, Attributes, IsDirectory, RelativePath).
*   **`FileSync.Core.DirectoryScanner`**: Class with `ScanDirectoryAsync` method to iteratively scan directories using metadata only.
    *   Handles basic access errors.
    *   Integrated into `FileSync.App`.
*   **`FileSync.Core.SyncEngine`**: Class with `SynchronizeAsync(..., SyncMode mode)` method to compare metadata and perform sync actions.
    *   Currently implements `--update` logic (copies new/newer files).
    *   Accepts `SyncMode` parameter.
    *   Uses `File.Copy` for file operations.
    *   Integrated into `FileSync.App`.
*   **`scripts/verify_milestone1.sh`**: Automated tests for project setup and basic CLI arguments.
*   **`scripts/verify_milestone2.sh`**: Automated tests for directory scanning functionality.
*   **`scripts/verify_milestone3.sh`**: Automated tests for `--update` mode synchronization logic.
*   **`scripts/verify_milestone4a.sh`**: Automated tests for `--update` CLI option and default behavior.
*   **`scripts/verify_milestone4b.sh`**: Automated tests for `--oneway` CLI option parsing and mutual exclusion.
*   **`scripts/verify_milestone4c.sh`**: Automated tests for `--threads` CLI option parsing and validation.

## CLI Arguments & Options

*   `source` (Argument, Required): Source directory.
*   `destination` (Argument, Required): Destination directory.
*   `--update` (Option, Boolean): Explicitly select update mode (default).
*   `--oneway` (Option, Boolean): Explicitly select one-way sync mode (mutually exclusive with --update).
*   `--threads <N>` (Option, Int32): Number of threads (default: processor count, must be > 0).
*   `--help`, `--version` (Built-in)

## Code Structure

*   Solution: `FileSync.sln`
*   Main Application: `src/FileSync.App` (Console App)
*   Core Logic Library: `src/FileSync.Core` (Class Library)
*   `FileSync.App` references `FileSync.Core`.
*   Modular design, avoid code duplication.
*   Target platforms will have specific builds, but share core logic. 