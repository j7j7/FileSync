using FileSync.Core.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace FileSync.Core;

/// <summary>
/// Defines the type of synchronization action needed.
/// </summary>
internal enum SyncActionType
{
    CreateDirectory,
    CopyFile
}

/// <summary>
/// Represents a planned synchronization action.
/// </summary>
internal record SyncAction(SyncActionType ActionType, FileMetadata SourceItem, string DestinationPath);

/// <summary>
/// Handles the logic for comparing source and destination items and performing synchronization actions.
/// </summary>
public class SyncEngine
{
    /// <summary>
    /// Performs the synchronization between source and destination based on the scanned metadata.
    /// Implements the '--update' logic: copy if source is newer or doesn't exist at destination.
    /// </summary>
    /// <param name="sourceItems">List of metadata for items in the source directory.</param>
    /// <param name="destinationItems">List of metadata for items in the destination directory.</param>
    /// <param name="sourceRoot">The root path of the source directory.</param>
    /// <param name="destinationRoot">The root path of the destination directory.</param>
    /// <param name="mode">The synchronization mode to use.</param>
    /// <returns>A task representing the asynchronous synchronization operation.</returns>
    public async Task SynchronizeAsync(List<FileMetadata> sourceItems, List<FileMetadata> destinationItems, string sourceRoot, string destinationRoot, SyncMode mode)
    {
        Console.WriteLine($"Comparing source and destination items (Mode: {mode})...");

        // Mode specific logic will be added/adjusted here later (especially for OneWay deletions)
        if (mode == SyncMode.OneWay)
        {
             Console.WriteLine("Warning: OneWay mode logic not yet fully implemented (no deletions).");
             Console.Out.Flush(); // Explicitly flush stdout
        }

        // 1. Create a lookup for destination items by relative path for efficient access.
        var destinationLookup = destinationItems.ToDictionary(item => item.RelativePath, item => item);

        var actionsToPerform = new List<SyncAction>();

        // 2. Iterate through source items to determine necessary actions.
        foreach (var sourceItem in sourceItems)
        {
            bool needsCopy = false;
            string potentialDestPath = Path.Combine(destinationRoot, sourceItem.RelativePath);

            if (destinationLookup.TryGetValue(sourceItem.RelativePath, out var destItem))
            {
                // Item exists in destination.
                // Check if source is a file and is newer than the destination file.
                // We only compare timestamps for files. Directory timestamps are less reliable for sync.
                if (!sourceItem.IsDirectory && !destItem.IsDirectory && sourceItem.LastWriteTimeUtc > destItem.LastWriteTimeUtc)
                {
                    // Source file is newer, mark for copy.
                    needsCopy = true;
                    Console.WriteLine($" -> Scheduling copy (newer): {sourceItem.RelativePath}");
                }
                // Handle cases where type differs (e.g., file in source, dir in dest)?
                // For now, we assume type consistency or overwrite based on timestamp.
                // `--oneway` mode will handle deletions later.
            }
            else
            {
                // Item does not exist in destination.
                needsCopy = true;
                Console.WriteLine($" -> Scheduling copy (new): {sourceItem.RelativePath}");
            }

            if (needsCopy)
            {
                if (sourceItem.IsDirectory)
                {
                    // If it's a directory that needs copying (because it's new),
                    // schedule directory creation.
                    actionsToPerform.Add(new SyncAction(SyncActionType.CreateDirectory, sourceItem, potentialDestPath));
                }
                else
                {
                    // If it's a file that needs copying (new or newer),
                    // schedule file copy.
                    actionsToPerform.Add(new SyncAction(SyncActionType.CopyFile, sourceItem, potentialDestPath));
                }
            }
        }

        Console.WriteLine($"Comparison complete. Found {actionsToPerform.Count} actions required.");

        // 3. Execute the planned actions.
        // Ensure directories are created before files within them might be copied.
        // Sort actions: CreateDirectory first, then CopyFile.
        foreach (var action in actionsToPerform.OrderBy(a => a.ActionType))
        {
            try
            {
                switch (action.ActionType)
                {
                    case SyncActionType.CreateDirectory:
                        if (!Directory.Exists(action.DestinationPath))
                        {
                            Console.WriteLine($"   Creating directory: {action.DestinationPath}");
                            Directory.CreateDirectory(action.DestinationPath);
                            // TODO: Consider copying directory attributes/timestamps if needed.
                        }
                        break;

                    case SyncActionType.CopyFile:
                        // Ensure the target directory exists (might have been created in a previous step
                        // or might already exist if only the file is newer).
                        string destDir = Path.GetDirectoryName(action.DestinationPath);
                        if (destDir != null && !Directory.Exists(destDir))
                        {
                             Console.WriteLine($"   Creating parent directory: {destDir}");
                             Directory.CreateDirectory(destDir);
                        }

                        Console.WriteLine($"   Copying file: {action.SourceItem.RelativePath} to {action.DestinationPath}");
                        // Use CopyFileAsync for potential future async benefits, though File.Copy is often sufficient.
                        // The 'true' argument overwrites the destination file if it already exists.
                        File.Copy(action.SourceItem.FullPath, action.DestinationPath, true);
                        // TODO: Add error handling for File.Copy
                        // TODO: Consider copying file attributes/timestamps if needed.
                        break;
                }
            }
            catch (Exception ex)
            {
                 // Log error and continue? Or stop?
                 // For now, log and continue is often preferred for sync tools.
                 Console.Error.WriteLine($"ERROR performing action {action.ActionType} for " +
                                           $"'{action.SourceItem.RelativePath}': {ex.Message}");
                 // Consider adding a summary of errors at the end.
            }
        }

        Console.WriteLine("Synchronization actions finished.");
        // No return value needed as it modifies files directly.
        await Task.CompletedTask; // Keep async signature for consistency
    }
} 