using System;

namespace FileSync.Core.Models;

/// <summary>
/// Represents a snapshot of the synchronization progress.
/// </summary>
/// <param name="Phase">The current phase of the operation (e.g., Scanning, Comparing, Copying, Deleting).</param>
/// <param name="ItemsProcessed">The number of items (files/directories) processed so far in the current phase.</param>
/// <param name="TotalItems">The total number of items expected to be processed in the current phase.</param>
/// <param name="BytesProcessed">The number of bytes processed so far (primarily relevant during copying).</param>
/// <param name="TotalBytes">The total number of bytes to be processed (primarily relevant during copying).</param>
/// <param name="ElapsedTime">The total time elapsed since the synchronization started.</param>
/// <param name="CurrentFile">The relative path of the file currently being processed, if applicable.</param>
public record ProgressReport(
    string Phase,
    long ItemsProcessed,
    long TotalItems,
    long BytesProcessed,
    long TotalBytes,
    TimeSpan ElapsedTime,
    string? CurrentFile = null
); 