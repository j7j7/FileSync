using System;
using System.CommandLine;
using System.CommandLine.Invocation;
using System.CommandLine.Parsing; // Required for ParseResult checks
using System.ComponentModel.DataAnnotations; // For Range validation attribute
using System.Text; // For StringBuilder
using System.Threading; // For Interlocked
using FileSync.Core;
using FileSync.Core.Models;

class Program
{
    // Shared state for progress handler (to clear previous line length)
    private static int _lastProgressLineLength = 0;

    static async Task<int> Main(string[] args)
    {
        // --- Arguments --- 
        var sourceArgument = new Argument<DirectoryInfo>(
            name: "source",
            description: "Source directory path.")
            {
                 Arity = ArgumentArity.ExactlyOne
            };

        var destinationArgument = new Argument<DirectoryInfo>(
            name: "destination",
            description: "Destination directory path.")
            {
                 Arity = ArgumentArity.ExactlyOne
            };

        // --- Options --- 
        var updateOption = new Option<bool>(
            name: "--update",
            description: "(Default) Copy new/newer files to destination. Leave extra destination files.");
            // Default is handled by checking if neither update nor oneway is explicitly true

        var oneWayOption = new Option<bool>(
            name: "--oneway",
            description: "Make destination an exact mirror of source (copies new/newer, deletes extra destination files).");

        var threadsOption = new Option<int>(
            name: "--threads",
            description: "Number of parallel threads to use for copy operations.",
            // Set default value factory
            getDefaultValue: () => Environment.ProcessorCount 
            );
        // Add validation for the threads option (must be > 0)
        // System.CommandLine supports Range validation out of the box
        threadsOption.AddValidator(result => 
        {
             int value = result.GetValueForOption(threadsOption); // Get the parsed value
             if (value <= 0)
             {
                 result.ErrorMessage = $"--threads must be a positive integer (value provided: {value}).";
             }
        });
        // Alternative using validation attributes (requires System.ComponentModel.DataAnnotations)
        // threadsOption.AddValidation(value => value > 0 ? null : "--threads must be a positive integer.");

        var testOption = new Option<bool>(
            name: "--test",
            description: "Output detailed step-by-step logs instead of single-line progress.");

        var rootCommand = new RootCommand("A fast and efficient file synchronization tool.")
        {
            sourceArgument,
            destinationArgument,
            updateOption,
            oneWayOption,
            threadsOption,
            testOption // Add the test option
        };

        // Add validator for mutually exclusive options
        rootCommand.AddValidator(result =>
        {
            if (result.GetValueForOption(updateOption) && result.GetValueForOption(oneWayOption))
            {
                // Using result.ErrorMessage directly is standard
                result.ErrorMessage = "Options --update and --oneway cannot be used together.";
                // Alternatively, for more complex validation messages:
                // context.AddError(new SymbolResultError(updateOption, "Cannot use --update and --oneway together."));
            }
        });

        rootCommand.SetHandler(async (InvocationContext context) =>
            {
                var parseResult = context.ParseResult;
                // --- Get Argument/Option Values --- 
                var source = parseResult.GetValueForArgument(sourceArgument);
                var destination = parseResult.GetValueForArgument(destinationArgument);
                bool isUpdateSpecified = parseResult.GetValueForOption(updateOption);
                bool isOneWaySpecified = parseResult.GetValueForOption(oneWayOption);
                int threadCount = parseResult.GetValueForOption(threadsOption);
                bool isTestMode = parseResult.GetValueForOption(testOption);

                int exitCode = 0;
                SyncMode effectiveMode;

                // --- Determine Effective Sync Mode --- 
                // Validator handles mutual exclusivity. If we get here, at most one is true.
                if (isOneWaySpecified)
                {
                    effectiveMode = SyncMode.OneWay;
                }
                else
                {
                    // Default to Update if --oneway isn't specified
                    // (This covers both no flag and explicit --update flag)
                    effectiveMode = SyncMode.Update;
                }

                // --- Path Validation (Existing) ---
                if (source == null || destination == null) { Console.Error.WriteLine("Error: Source and destination arguments are required."); exitCode = 1; }
                else
                {
                    if (!source.Exists) { Console.Error.WriteLine($"Error: Source directory not found: {source.FullName}"); exitCode = 1; }
                    else if (!destination.Exists) { Console.Error.WriteLine($"Error: Destination directory not found: {destination.FullName}"); exitCode = 1; }
                }
                // --- End Path Validation ---

                if (exitCode == 0)
                {
                    // --- Setup Progress Reporting (if not in test mode) ---
                    IProgress<ProgressReport>? progressReporter = null;
                    if (!isTestMode)
                    {
                        // Hide cursor during progress updates
                        try { Console.CursorVisible = false; }
                        catch (IOException) { /* Ignore if not supported */ }

                        progressReporter = new Progress<ProgressReport>(report =>
                        {
                            HandleProgressReport(report);
                        });
                        // Don't print "Starting..." - the progress bar will show activity
                    }
                    else
                    {
                        Console.WriteLine("Starting FileSync..."); // Keep for test mode
                        Console.WriteLine($"Source: {source!.FullName}"); // Use null-forgiving operator
                        Console.WriteLine($"Destination: {destination!.FullName}"); // Use null-forgiving operator
                        Console.WriteLine($"Sync Mode: {effectiveMode}");
                        Console.WriteLine($"Threads: {threadCount}");
                        Console.WriteLine("Test Mode: Enabled");
                    }

                    var scanner = new DirectoryScanner();
                    List<FileMetadata> sourceItems = new List<FileMetadata>();
                    List<FileMetadata> destItems = new List<FileMetadata>();
                    try
                    {
                        if(isTestMode) Console.WriteLine("Scanning source directory...");
                        // Pass progress reporter to scanner
                        sourceItems = await scanner.ScanDirectoryAsync(source!.FullName, progressReporter); // Use null-forgiving operator
                        if(isTestMode) Console.WriteLine($"Found {sourceItems.Count} items in source.");

                        if(isTestMode) Console.WriteLine("Scanning destination directory...");
                        // Pass progress reporter to scanner
                        destItems = await scanner.ScanDirectoryAsync(destination!.FullName, progressReporter); // Use null-forgiving operator
                        if(isTestMode) Console.WriteLine($"Found {destItems.Count} items in destination.");

                        if (sourceItems.Any() || destItems.Any() || effectiveMode == SyncMode.OneWay)
                        {
                             if(isTestMode) Console.WriteLine($"Starting synchronization ({effectiveMode} mode)..." );
                             var syncEngine = new SyncEngine();
                             // Pass test mode flag AND progress reporter to sync engine
                             await syncEngine.SynchronizeAsync(sourceItems, destItems, source!.FullName, destination!.FullName, effectiveMode, threadCount, isTestMode, progressReporter); // Use null-forgiving operator
                             // Test mode already prints "Synchronization complete." inside engine
                        }
                        else 
                        { 
                             if(isTestMode) Console.WriteLine("Source and destination are empty or identical. Nothing to synchronize."); 
                             // Provide minimal non-test output
                             else Console.WriteLine("Source and destination are empty or identical. Nothing to synchronize.");
                        }
                    }
                    catch (Exception ex)
                    {
                         // Ensure progress line is cleared before writing error
                         if (!isTestMode) ClearCurrentConsoleLine();
                         Console.Error.WriteLine($"\nAn error occurred during synchronization: {ex.Message}");
                         // Consider logging full stack trace in verbose/debug mode later
                         exitCode = 1;
                    }
                    finally
                    {
                        // --- Clean up Progress Reporting ---
                        if (!isTestMode)
                        {
                            // Don't clear the final progress line, just restore cursor visibility
                            try { Console.CursorVisible = true; } 
                            catch (IOException) { /* Ignore if not supported */ }
                        }
                    }

                    // Final success message (if no errors occurred)
                    if (exitCode == 0)
                    {
                        // No extra message needed in test mode (engine logs completion)
                        if (!isTestMode)
                        {
                             Console.WriteLine(); // Add a new line before the completion message
                             Console.WriteLine("FileSync finished successfully.");
                        }
                    }
                    else 
                    {
                         if (!isTestMode)
                         {
                             Console.WriteLine(); // Add a new line before the error message
                             Console.WriteLine("FileSync finished with errors."); // Indicate failure
                         }
                         // Test mode relies on error messages already printed
                    }
                }

                context.ExitCode = exitCode;
            });

        return await rootCommand.InvokeAsync(args);
    }

    /// <summary>
    /// Handles progress reports by updating a single line in the console.
    /// </summary>
    private static void HandleProgressReport(ProgressReport report)
    {
        try
        {
            // Always write to the first line
            Console.SetCursorPosition(0, 0);
            
            var sb = new StringBuilder();
            
            // Map phase names to shorter versions
            string phase = report.Phase switch
            {
                "Scanning" => "Scan",
                "CreateDirectory" => "MKDIR",
                "CopyFile" => "Copy",
                _ => report.Phase
            };
            
            sb.AppendFormat("{0,-8}", phase); // Reduced from 15 to 8 chars

            double percentage = 0;
            if (report.TotalItems > 0)
            {
                percentage = (double)report.ItemsProcessed / report.TotalItems;
            }
            else if (report.Phase == "Scanning" && report.ItemsProcessed > 0) 
            { 
                 // Indicate activity during scanning even without total
                 sb.Append("[...] ");
            }
            
            if (report.TotalItems >= 0) // Show percentage if total is known
            {
                sb.AppendFormat("[{0,-10}] {1,3:P0} ", 
                    new string('=', (int)(percentage * 10)), 
                    percentage);
            }

            // Item Counts - removed "Items:" text
            if (report.TotalItems >= 0)
            { sb.AppendFormat("{0}/{1} ", report.ItemsProcessed, report.TotalItems); }
            else if (report.Phase == "Scanning")
            { sb.AppendFormat("{0} ", report.ItemsProcessed); }

            // Byte Counts (only if relevant, e.g., CopyFile)
            if (report.TotalBytes > 0)
            { 
                sb.AppendFormat("({0:F1}/{1:F1}MB) ", 
                    (double)report.BytesProcessed / (1024 * 1024), 
                    (double)report.TotalBytes / (1024 * 1024)); 
            }

            // Elapsed Time
            sb.AppendFormat("{0} ", report.ElapsedTime.ToString(@"hh\:mm\:ss"));

            // Current File (truncate if needed)
            if (!string.IsNullOrEmpty(report.CurrentFile))
            {
                int availableWidth = Console.WindowWidth - sb.Length - 3; // -3 for "| " and safety
                if (availableWidth > 5) // Only show if there's reasonable space
                {
                    string file = report.CurrentFile;
                    if (file.Length > 40) // Max 40 chars for the file part
                    {
                        // Get just the filename part
                        int lastSlash = file.LastIndexOfAny(new[] { '/', '\\' });
                        if (lastSlash > 0)
                        {
                            string filename = file.Substring(lastSlash + 1);
                            if (filename.Length > 40)
                            {
                                // If filename is too long, truncate it
                                filename = "..." + filename.Substring(filename.Length - 37);
                            }
                            file = filename;
                        }
                        else
                        {
                            // If no path separator, just truncate the whole thing
                            file = "..." + file.Substring(file.Length - 37);
                        }
                    }
                    sb.Append("| " + file);
                }
            }

            string output = sb.ToString();
            
            // Ensure output doesn't exceed console width
            if (output.Length > Console.WindowWidth - 1)
            {
                output = output.Substring(0, Console.WindowWidth - 1);
            }
            
            // Clear the line and write new output
            Console.Write(new string(' ', Console.WindowWidth - 1));
            Console.SetCursorPosition(0, 0);
            Console.Write(output);
        }
        catch (IOException) { /* Console redirection or other issues */ return; }
    }

    /// <summary>
    /// Clears the current console line from the current cursor position.
    /// </summary>
    private static void ClearCurrentConsoleLine()
    {
        try
        {
            Console.SetCursorPosition(0, 0);
            Console.Write(new string(' ', Console.WindowWidth - 1));
            Console.SetCursorPosition(0, 0);
        }
        catch (IOException) { /* Ignore if not supported */ }
    }
}
