namespace FileSync.Core.Models;

/// <summary>
/// Represents metadata for a file or directory item during scanning.
/// </summary>
public record FileMetadata
{
    /// <summary>
    /// Gets the full path to the file or directory.
    /// </summary>
    public required string FullPath { get; init; }

    /// <summary>
    /// Gets the path relative to the root directory being scanned.
    /// </summary>
    public required string RelativePath { get; init; }

    /// <summary>
    /// Gets the name of the file or directory.
    /// </summary>
    public required string Name { get; init; }

    /// <summary>
    /// Gets the size of the file in bytes. Returns 0 for directories.
    /// </summary>
    public long SizeBytes { get; init; }

    /// <summary>
    /// Gets the last write time (UTC) of the file or directory.
    /// </summary>
    public DateTime LastWriteTimeUtc { get; init; }

    /// <summary>
    /// Gets a value indicating whether this item is a directory.
    /// </summary>
    public bool IsDirectory { get; init; }

    /// <summary>
    /// Gets the file attributes.
    /// Important for detecting special files like cloud stubs later.
    /// </summary>
    public FileAttributes Attributes { get; init; }
} 