# --- CONFIGURATION ---
$outputFile = "output.txt"

# Add directory names here that you want to skip entirely.
# Example: @("styles","components/ui") ignores all files in ./styles and ./components/ui directories.
$ignoredDirectories = @() 
# ---------------------

# Ensure Git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git command not found. Please ensure Git is installed and in your PATH."
    exit 1
}

Write-Host "Getting files from git..."

# Build the regex pattern for ignored directories
$dirPattern = if ($ignoredDirectories) {
    '^(' + ($ignoredDirectories -join '|') + ')/'
} else {
    '^$' # Matches nothing if array is empty
}

# Get files from git and filter them
$files = git ls-files | Where-Object {
    # 1. Filter out the user-defined ignored directories
    $_ -notmatch $dirPattern -and
    # 2. Filter out file extensions and system folders
    $_ -notmatch '\.(exe|dll|obj|bin|pdb|cache|log|md)$' -and
    $_ -notmatch '\.(jpg|jpeg|png|gif|bmp|ico|svg|webp|tiff)$' -and
    $_ -notmatch '(packages|target)/' -and
    $_ -notmatch '(\.vs|\.vscode|\.idea)/' -and
    $_ -notmatch '\.(min\.js|min\.css)$' -and
    $_ -notmatch '(\.git|\.DS_Store)' -and
    $_ -notmatch '(package-lock\.json|yarn\.lock|npm-shrinkwrap\.json)$' -and
    $_ -notmatch '\.(csproj|sln|nuspec|nupkg)$'
} | Sort-Object

if (-not $files) {
    Write-Warning "No files matched the criteria or no files are tracked by Git. Exiting."
    exit
}

Write-Host "Found $($files.Count) files matching criteria."

# Create the output file with the header
"--- START OF FILE output.txt ---" | Set-Content -LiteralPath $outputFile -Encoding UTF8
"" | Add-Content -LiteralPath $outputFile -Encoding UTF8
"File list:" | Add-Content -LiteralPath $outputFile -Encoding UTF8

# --- Add the flat list of file paths ---
foreach ($file in $files) {
    $normalizedPath = $file.Replace('\', '/')
    Add-Content -LiteralPath $outputFile -Value $normalizedPath -Encoding UTF8
}

"" | Add-Content -LiteralPath $outputFile -Encoding UTF8
"===" | Add-Content -LiteralPath $outputFile -Encoding UTF8
"" | Add-Content -LiteralPath $outputFile -Encoding UTF8

# Add each file's content
$fileCounter = 0
$totalFiles = $files.Count
foreach ($file in $files) {
    $fileCounter++
    Write-Progress -Activity "Adding file content" -Status "Processing $file ($fileCounter/$totalFiles)" -PercentComplete (($fileCounter / $totalFiles) * 100)

    Add-Content -LiteralPath $outputFile -Value $file -Encoding UTF8

    try {
        # Using -LiteralPath to handle [handle] and [id] edge cases
        if (Test-Path -LiteralPath $file -PathType Leaf) {
            $fileContent = Get-Content -LiteralPath $file -Raw -Encoding UTF8 -ErrorAction Stop
            Add-Content -LiteralPath $outputFile -Value "" -Encoding UTF8
            Add-Content -LiteralPath $outputFile -Value $fileContent -Encoding UTF8
        } else {
            Write-Warning "File listed by git not found on disk: '$file'"
            Add-Content -LiteralPath $outputFile -Value "" -Encoding UTF8
            Add-Content -LiteralPath $outputFile -Value "[File not found on disk]" -Encoding UTF8
        }
    } catch {
        Write-Warning "Error reading file '$file': $($_.Exception.Message)"
        Add-Content -LiteralPath $outputFile -Value "" -Encoding UTF8
        Add-Content -LiteralPath $outputFile -Value "[Error reading file content: $($_.Exception.Message)]" -Encoding UTF8
    }

    if ($fileCounter -lt $totalFiles) {
        Add-Content -LiteralPath $outputFile -Value "" -Encoding UTF8
        Add-Content -LiteralPath $outputFile -Value "===" -Encoding UTF8
        Add-Content -LiteralPath $outputFile -Value "" -Encoding UTF8
    } else {
        Add-Content -LiteralPath $outputFile -Value "" -Encoding UTF8
    }
}

Write-Progress -Activity "Adding file content" -Completed
Write-Host "Processing complete. Output written to $outputFile"



