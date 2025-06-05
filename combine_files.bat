@echo off
setlocal EnableDelayedExpansion

:: Set output file name
set "output_file=combined_output.txt"

:: Clear output file if it exists
if exist "%output_file%" del "%output_file%"

:: Iterate through all files in current directory and subdirectories
for /r %%F in (*) do (
    :: Skip the output file, the batch file itself, files in .git folders, and tf_test.pem
    if /i not "%%F"=="%~f0" if /i not "%%F"=="%cd%\%output_file%" if /i not "%%~nxF"=="tf_test.pem" (
        :: Check if the file path contains .git
        echo "%%F" | findstr /i "\.git\\" >nul
        if !errorlevel! neq 0 (
            :: Write file path as title
            echo %%F>>"%output_file%"
            echo --------------------------------------------->>"%output_file%"
            
            :: Try to read and append file content
            type "%%F">>"%output_file%" 2>nul
            
            :: Add separator
            echo.>>"%output_file%"
            echo.>>"%output_file%"
        )
    )
)

echo Done! Combined file created: %output_file%
pause