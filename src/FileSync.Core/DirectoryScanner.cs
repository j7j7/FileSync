using FileSync.Core.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace FileSync.Core;

/// <summary>
/// Provides functionality to scan directories for file metadata.
/// </summary>
public class DirectoryScanner
{
    /// <summary>
    /// Asynchronously scans the specified directory recursively and returns metadata for all files and subdirectories.
    /// </summary>
    /// <param name="directoryPath">The absolute path of the directory to scan.</param>
    /// <returns>A list of FileMetadata objects representing the items found.</returns>
    /// <exception cref="DirectoryNotFoundException">Thrown if the specified directory does not exist.</exception>
    /// <remarks>
    /// This method currently executes synchronously despite the async signature, returning a completed task.
    /// True asynchronicity might be added later if needed, potentially with parallel enumeration.
    /// Errors accessing specific files/subdirectories are logged to Console.Error and the item is skipped.
    /// </remarks>
    public Task<List<FileMetadata>> ScanDirectoryAsync(string directoryPath)
    {
        var rootDirectoryInfo = new DirectoryInfo(directoryPath);
        if (!rootDirectoryInfo.Exists)
        {
            throw new DirectoryNotFoundException($"Directory not found: {directoryPath}");
        }

        var metadataList = new List<FileMetadata>();
        var directoriesToScan = new Stack<DirectoryInfo>();
        directoriesToScan.Push(rootDirectoryInfo);

        // Keep track of the root path length to calculate relative paths correctly, including the directory separator.
        // Ensure the root path ends with a separator for consistent relative path calculation.
        string normalizedRootPath = Path.GetFullPath(directoryPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
        int rootPathLength = normalizedRootPath.Length;


        while (directoriesToScan.Count > 0)
        {
            var currentDirInfo = directoriesToScan.Pop();

            // Optional: Add metadata for the directory itself if needed
            // We are primarily interested in files for sync, but might need dirs later.
            // For now, we just scan *within* the directory.

            try
            {
                // Use EnumerateFileSystemInfos for efficiency (yields results)
                // Request FileSystemInfo directly to avoid extra calls later
                foreach (var fsInfo in currentDirInfo.EnumerateFileSystemInfos("*", SearchOption.TopDirectoryOnly))
                {
                    try
                    {
                        bool isDirectory = (fsInfo.Attributes & FileAttributes.Directory) == FileAttributes.Directory;

                        // Calculate relative path
                        string relativePath = fsInfo.FullName.Substring(rootPathLength);

                        metadataList.Add(new FileMetadata
                        {
                            FullPath = fsInfo.FullName,
                            RelativePath = relativePath,
                            Name = fsInfo.Name,
                            SizeBytes = isDirectory ? 0 : ((FileInfo)fsInfo).Length, // Size is 0 for dirs
                            LastWriteTimeUtc = fsInfo.LastWriteTimeUtc,
                            IsDirectory = isDirectory,
                            Attributes = fsInfo.Attributes
                        });

                        // If it's a directory, add it to the stack to scan its contents
                        if (isDirectory)
                        {
                            directoriesToScan.Push((DirectoryInfo)fsInfo);
                        }
                    }
                    catch (UnauthorizedAccessException ex)
                    {
                        Console.Error.WriteLine($"Access denied scanning: {fsInfo.FullName}. Skipping. Error: {ex.Message}");
                    }
                    catch (IOException ex)
                    {
                         Console.Error.WriteLine($"IO error scanning: {fsInfo.FullName}. Skipping. Error: {ex.Message}");
                    }
                     catch (Exception ex) // Catch other potential errors during metadata access
                    {
                        Console.Error.WriteLine($"Unexpected error accessing metadata for: {fsInfo?.FullName ?? currentDirInfo.FullName}. Skipping. Error: {ex.Message}");
                    }
                }
            }
            catch (UnauthorizedAccessException ex)
            {
                 Console.Error.WriteLine($"Access denied enumerating directory: {currentDirInfo.FullName}. Skipping. Error: {ex.Message}");
            }
            catch (IOException ex)
            {
                 Console.Error.WriteLine($"IO error enumerating directory: {currentDirInfo.FullName}. Skipping. Error: {ex.Message}");
            }
            catch (Exception ex) // Catch other potential errors during enumeration
            {
                Console.Error.WriteLine($"Unexpected error enumerating directory: {currentDirInfo.FullName}. Skipping. Error: {ex.Message}");
            }
        }

        // Although the method is synchronous internally, we return a completed task
        // to match the async method signature.
        return Task.FromResult(metadataList);
    }
} 