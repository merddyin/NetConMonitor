filter Test-FileInput {
    (
        [string]$FilePath
    )
    {
        switch ($FilePath) {
            {-not (Test-Path $FilePath -IsValid)} { Throw "The specified file path does not exist." }
            {-not (Test-Path $FilePath -PathType 'leaf')} { Throw "The specified path must be to file." }
            {-not (Get-Content $FilePath)} { Throw "The specified file is empty." }
            {-not ($FilePath -match '(\.csv$|\.txt)')} { Throw "The specified file must be either a TXT or CSV file." }
            Default {$true}
        }
    }
}