using FileSync.Core.Models;
using System;
using System.Collections.Generic;
using System.Diagnostics; // Added for Stopwatch
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Concurrent; // For thread-safe collections if needed

namespace FileSync.Core;

/// <summary>
/// Defines the type of synchronization action needed.
/// </summary>
internal enum SyncActionType
{
    CreateDirectory,
    CopyFile,
    DeleteFile,
    DeleteDirectory
}

/// <summary>
/// Represents a planned synchronization action.
/// Note: SourceItem might be null for Delete actions, as the item doesn't exist in the source.
/// </summary>
internal record SyncAction(
    SyncActionType ActionType,
    FileMetadata? SourceItem, // Null for delete actions originating from destination check
    FileMetadata? DestinationItem, // Null for create/copy actions originating from source check
    string Path // Represents DestinationPath for Create/Copy, PathToDelete for Delete
);

/// <summary>
/// Handles the logic for comparing source and destination items and performing synchronization actions.
/// </summary>
public class SyncEngine
{
    /// <summary>
    /// Performs the synchronization between source and destination based on the scanned metadata.
    /// </summary>
    /// <param name="sourceItems">List of metadata for items in the source directory.</param>
    /// <param name="destinationItems">List of metadata for items in the destination directory.</param>
    /// <param name="sourceRoot">The root path of the source directory.</param>
    /// <param name="destinationRoot">The root path of the destination directory.</param>
    /// <param name="mode">The synchronization mode to use.</param>
    /// <param name="threadCount">Maximum number of threads to use for parallel operations.</param>
    /// <param name="isTestMode">If true, output detailed logs; otherwise, do not log standard operations.</param>
    /// <param name="progress">Optional progress reporter.</param>
    /// <returns>A task representing the asynchronous synchronization operation.</returns>
    public async Task SynchronizeAsync(
        List<FileMetadata> sourceItems, 
        List<FileMetadata> destinationItems, 
        string sourceRoot, 
        string destinationRoot, 
        SyncMode mode, 
        int threadCount,
        bool isTestMode,
        IProgress<ProgressReport>? progress = null)
    {
        var stopwatch = Stopwatch.StartNew(); // Start timing overall operation

        // Simple logger: logs to Console.WriteLine if isTestMode is true, otherwise does nothing.
        Action<string> log = isTestMode ? Console.WriteLine : (Action<string>)(_ => { });
        // Errors should always be logged regardless of test mode.
        Action<string> logError = Console.Error.WriteLine;

        log($"Comparing source and destination items (Mode: {mode}, Threads: {threadCount})...");

        // Report start of comparison (can't easily track item-by-item progress here without more loops)
        progress?.Report(new ProgressReport("Comparing", 0, -1, 0, -1, stopwatch.Elapsed));

        // --- Steps 1-3: Determine Actions (Same as before) ---
        var destinationLookup = destinationItems.ToDictionary(item => item.RelativePath, item => item);
        var sourceLookup = sourceItems.ToDictionary(item => item.RelativePath, item => item);
        var actionsToPerform = new List<SyncAction>();
        // --- Populate Create/Copy Actions --- 
        foreach (var sourceItem in sourceItems)
        {
            bool needsCopy = false;
            string potentialDestPath = Path.Combine(destinationRoot, sourceItem.RelativePath);

            if (destinationLookup.TryGetValue(sourceItem.RelativePath, out var destItem))
            {
                if (!sourceItem.IsDirectory && !destItem.IsDirectory && sourceItem.LastWriteTimeUtc > destItem.LastWriteTimeUtc)
                { needsCopy = true; log($" -> Scheduling copy (newer): {sourceItem.RelativePath}"); }
            }
            else
            { needsCopy = true; log($" -> Scheduling copy/create (new): {sourceItem.RelativePath}"); }

            if (needsCopy)
            {
                if (sourceItem.IsDirectory)
                { actionsToPerform.Add(new SyncAction(SyncActionType.CreateDirectory, sourceItem, null, potentialDestPath)); }
                else
                { actionsToPerform.Add(new SyncAction(SyncActionType.CopyFile, sourceItem, null, potentialDestPath)); }
            }
        }
        // --- Populate Delete Actions (OneWay only) ---
         if (mode == SyncMode.OneWay)
        {
            foreach (var destItem in destinationItems)
            {
                if (!sourceLookup.ContainsKey(destItem.RelativePath))
                {
                    log($" -> Scheduling delete (extra): {destItem.RelativePath}");
                    if (destItem.IsDirectory)
                    { actionsToPerform.Add(new SyncAction(SyncActionType.DeleteDirectory, null, destItem, destItem.FullPath)); }
                    else
                    { actionsToPerform.Add(new SyncAction(SyncActionType.DeleteFile, null, destItem, destItem.FullPath)); }
                }
            }
        }
         // --- End Determine Actions --- 

        log($"Comparison complete. Found {actionsToPerform.Count} actions required.");
        progress?.Report(new ProgressReport("Comparison Complete", actionsToPerform.Count, actionsToPerform.Count, 0, -1, stopwatch.Elapsed)); // Report end of comparison

        if (actionsToPerform.Count == 0)
        {
             log("No actions needed. Directories are in sync.");
             stopwatch.Stop();
             return;
        }

        // --- Calculate Totals for Progress Reporting ---
        long totalCreateDirs = actionsToPerform.LongCount(a => a.ActionType == SyncActionType.CreateDirectory);
        long totalCopyFiles = actionsToPerform.LongCount(a => a.ActionType == SyncActionType.CopyFile);
        long totalCopyBytes = actionsToPerform.Where(a => a.ActionType == SyncActionType.CopyFile && a.SourceItem != null).Sum(a => a.SourceItem!.SizeBytes);
        long totalDeleteFiles = actionsToPerform.LongCount(a => a.ActionType == SyncActionType.DeleteFile);
        long totalDeleteDirs = actionsToPerform.LongCount(a => a.ActionType == SyncActionType.DeleteDirectory);

        // --- Initialize Thread-Safe Counters ---
        long processedCreateDirs = 0;
        long processedCopyFiles = 0;
        long processedCopyBytes = 0;
        long processedDeleteFiles = 0;
        long processedDeleteDirs = 0;

        // --- Execute Actions (Parallel where appropriate) ---
        var executionOrder = new Dictionary<SyncActionType, int>
        {
            { SyncActionType.CreateDirectory, 1 },
            { SyncActionType.CopyFile, 2 },
            { SyncActionType.DeleteFile, 3 },
            { SyncActionType.DeleteDirectory, 4 }
        };

        var groupedActions = actionsToPerform.GroupBy(a => a.ActionType)
                                             .OrderBy(g => executionOrder[g.Key]);
        
        var parallelOptions = new ParallelOptions
        {
            MaxDegreeOfParallelism = threadCount
        };

        foreach (var group in groupedActions)
        {
            SyncActionType currentActionType = group.Key;
            // Log start of phase only in test mode
            if(isTestMode) log($"\n--- Executing {currentActionType} actions ---");

            // Calculate phase totals for progress reporting
             string currentPhase = currentActionType.ToString(); // e.g., "CopyFile"
             long currentTotalItems = 0;
             long currentTotalBytes = 0;
             switch(currentActionType)
             {
                 case SyncActionType.CreateDirectory: currentTotalItems = totalCreateDirs; break;
                 case SyncActionType.CopyFile: currentTotalItems = totalCopyFiles; currentTotalBytes = totalCopyBytes; break;
                 case SyncActionType.DeleteFile: currentTotalItems = totalDeleteFiles; break;
                 case SyncActionType.DeleteDirectory: currentTotalItems = totalDeleteDirs; break;
             }
            // Report start of the action phase (regardless of test mode)
             progress?.Report(new ProgressReport(currentPhase, 0, currentTotalItems, 0, currentTotalBytes, stopwatch.Elapsed));

            var orderedActionsInGroup = group
                 .OrderByDescending(a => (a.ActionType == SyncActionType.DeleteFile || a.ActionType == SyncActionType.DeleteDirectory) ? a.Path.Length : 0) 
                 .ThenBy(a => (a.ActionType == SyncActionType.CreateDirectory || a.ActionType == SyncActionType.CopyFile) ? a.Path.Length : 0);

            if (currentActionType == SyncActionType.CopyFile || currentActionType == SyncActionType.DeleteFile || currentActionType == SyncActionType.DeleteDirectory)
            {
                // Parallel Execution
                await Parallel.ForEachAsync(orderedActionsInGroup, parallelOptions, async (action, cancellationToken) => 
                {
                    try
                    { 
                        // Log action start only in test mode
                        if(isTestMode) log($"   Starting {action.ActionType}: {action.SourceItem?.RelativePath ?? action.DestinationItem?.RelativePath ?? action.Path}");
                        await ExecuteSingleActionAsync(action, logError); // Call updated helper
                        if(isTestMode) log($"   Finished {action.ActionType}: {action.SourceItem?.RelativePath ?? action.DestinationItem?.RelativePath ?? action.Path}");

                        // --- Report Progress (Thread-Safe) ---
                        string? itemPath = action.SourceItem?.RelativePath ?? action.DestinationItem?.RelativePath;
                        long itemBytes = 0;
                        long itemsDone = 0;
                        long bytesDone = 0;

                        switch(action.ActionType)
                        {
                            case SyncActionType.CopyFile:
                                itemBytes = action.SourceItem?.SizeBytes ?? 0;
                                itemsDone = Interlocked.Increment(ref processedCopyFiles);
                                bytesDone = Interlocked.Add(ref processedCopyBytes, itemBytes);
                                break;
                            case SyncActionType.DeleteFile:
                                itemsDone = Interlocked.Increment(ref processedDeleteFiles);
                                break;
                             case SyncActionType.DeleteDirectory:
                                itemsDone = Interlocked.Increment(ref processedDeleteDirs);
                                break;
                        }
                        progress?.Report(new ProgressReport(currentPhase, itemsDone, currentTotalItems, bytesDone, currentTotalBytes, stopwatch.Elapsed, itemPath));
                    }
                    catch
                    {
                        // Error already logged by ExecuteSingleActionAsync
                        // Optionally report error progress?
                        // We might add a counter for errors here later.
                    }
                });
            }
            else // CreateDirectory - execute sequentially
            {
                 foreach (var action in orderedActionsInGroup)
                 {
                      try 
                      { 
                          // Log action start only in test mode
                          if(isTestMode) log($"   Starting {action.ActionType}: {action.SourceItem?.RelativePath ?? action.DestinationItem?.RelativePath ?? action.Path}");
                          await ExecuteSingleActionAsync(action, logError); // Call updated helper
                          if(isTestMode) log($"   Finished {action.ActionType}: {action.SourceItem?.RelativePath ?? action.DestinationItem?.RelativePath ?? action.Path}");

                          // --- Report Progress (Sequential) ---
                           string? itemPath = action.SourceItem?.RelativePath;
                           long itemsDone = Interlocked.Increment(ref processedCreateDirs);
                           progress?.Report(new ProgressReport(currentPhase, itemsDone, currentTotalItems, 0, 0, stopwatch.Elapsed, itemPath));
                      }
                      catch
                      {
                           // Error already logged by ExecuteSingleActionAsync
                           // Optionally report error progress?
                      }
                 }
            }
        }
        stopwatch.Stop();
        // Log overall finish only in test mode
        if(isTestMode) log("\nSynchronization actions finished.");
        // Final progress report might be useful (e.g., show 100% completion)
        // We need the totals from the last phase executed.
         var lastPhaseReport = new ProgressReport("Finished", 
                                                 processedCreateDirs + processedCopyFiles + processedDeleteFiles + processedDeleteDirs, 
                                                 totalCreateDirs + totalCopyFiles + totalDeleteFiles + totalDeleteDirs, 
                                                 processedCopyBytes, 
                                                 totalCopyBytes, 
                                                 stopwatch.Elapsed);
        progress?.Report(lastPhaseReport);
    }

    /// <summary>
    /// Executes a single synchronization action. Focuses on the IO operation.
    /// </summary>
    /// <param name="action">The action to execute.</param>
    /// <param name="logError">Action to log errors.</param>
    private async Task ExecuteSingleActionAsync(SyncAction action, Action<string> logError)
    {
        // Note: Logging of the operation start/finish is now handled by the caller IF isTestMode is true.
        // We only perform the operation and handle/log errors here.
        try
        {
            switch (action.ActionType)
            {
                case SyncActionType.CreateDirectory:
                    if (!Directory.Exists(action.Path))
                    {
                        Directory.CreateDirectory(action.Path);
                    }
                    break;

                case SyncActionType.CopyFile:
                    if (action.SourceItem == null) { throw new InvalidOperationException("SourceItem cannot be null for CopyFile action."); }

                    string destDir = Path.GetDirectoryName(action.Path) ?? throw new InvalidOperationException($"Could not determine directory for {action.Path}");
                    // Ensure parent directory exists (might have been created by another thread or sequentially)
                    // No need to explicitly check/create if Directory.CreateDirectory handles it, but File.Copy might fail if parent doesn't exist
                     if (!Directory.Exists(destDir))
                     {
                         Directory.CreateDirectory(destDir);
                     }
                    // Perform the copy, overwriting if the destination exists.
                    File.Copy(action.SourceItem.FullPath, action.Path, true);
                    break;

                case SyncActionType.DeleteFile:
                    if (File.Exists(action.Path))
                    {
                        File.Delete(action.Path);
                    }
                    // else: If it doesn't exist, the goal is achieved, no error.
                    break;

                case SyncActionType.DeleteDirectory:
                    if (Directory.Exists(action.Path))
                    {
                         // Recursively delete.
                        Directory.Delete(action.Path, true);
                    }
                     // else: If it doesn't exist, the goal is achieved, no error.
                    break;
            }
        }
        catch (Exception ex)
        {
            // Log the specific error and rethrow to be caught by the caller loop
             logError($"ERROR during {action.ActionType} for '{action.Path}': {ex.Message}");
             throw; // Rethrow the exception to be handled by the Parallel.ForEachAsync or sequential loop's catch block
        }

        await Task.CompletedTask; // Keep async signature
    }
} 