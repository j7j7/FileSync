using System.CommandLine;
using System.CommandLine.Invocation;
using System.CommandLine.Parsing; // Required for ParseResult checks
using System.ComponentModel.DataAnnotations; // For Range validation attribute
using FileSync.Core;
using FileSync.Core.Models;

class Program
{
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

        var rootCommand = new RootCommand("A fast and efficient file synchronization tool.")
        {
            sourceArgument,
            destinationArgument,
            updateOption,
            oneWayOption,
            threadsOption // Add the threads option
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
                int threadCount = parseResult.GetValueForOption(threadsOption); // Get thread count

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
                    Console.WriteLine($"Source: {source.FullName}");
                    Console.WriteLine($"Destination: {destination.FullName}");
                    Console.WriteLine($"Sync Mode: {effectiveMode}");
                    Console.WriteLine($"Threads: {threadCount}"); // Display thread count

                    var scanner = new DirectoryScanner();
                    List<FileMetadata> sourceItems = new List<FileMetadata>();
                    List<FileMetadata> destItems = new List<FileMetadata>();
                    try
                    {
                        Console.WriteLine("Scanning source directory...");
                        sourceItems = await scanner.ScanDirectoryAsync(source.FullName);
                        Console.WriteLine($"Found {sourceItems.Count} items in source.");

                        Console.WriteLine("Scanning destination directory...");
                        destItems = await scanner.ScanDirectoryAsync(destination.FullName);
                        Console.WriteLine($"Found {destItems.Count} items in destination.");

                        if (sourceItems.Any() || destItems.Any())
                        {
                             Console.WriteLine($"Starting synchronization ({effectiveMode} mode)..." );
                             var syncEngine = new SyncEngine();
                             await syncEngine.SynchronizeAsync(sourceItems, destItems, source.FullName, destination.FullName, effectiveMode);
                             Console.WriteLine("Synchronization complete.");
                        }
                        else { Console.WriteLine("Source and destination are empty. Nothing to synchronize."); }
                    }
                    catch (Exception ex)
                    {
                         Console.Error.WriteLine($"An error occurred during scanning or synchronization: {ex.Message}");
                         exitCode = 1;
                    }
                }

                context.ExitCode = exitCode;
            });

        return await rootCommand.InvokeAsync(args);
    }
}
