namespace FileSync.Core;

/// <summary>
/// Defines the overall synchronization strategy.
/// </summary>
public enum SyncMode
{
    /// <summary>
    /// Copy new/newer files from source to destination. Leave destination-only files.
    /// </summary>
    Update,

    /// <summary>
    /// Make destination an exact mirror of source. Copy new/newer files, delete destination-only files.
    /// </summary>
    OneWay
} 