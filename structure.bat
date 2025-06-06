@echo off
setlocal EnableDelayedExpansion

:: Set output file name
set "output_file=directory_structure.txt"

:: Clear output file if it exists
if exist "%output_file%" del "%output_file%"

:: Write header to output file
echo Directory Structure of %CD%>>"%output_file%"
echo Generated on %DATE% %TIME%>>"%output_file%"
echo.>>"%output_file%"

:: Use tree command for visual structure, excluding .git and .terraform
echo Folders:>>"%output_file%"
tree /f /a | findstr /v /i "\.git\|\.terraform\|%output_file%\|%~nx0" >>"%output_file%"

:: Add list of files with full paths, excluding .git, .terraform, and tf_test.pem
echo.>>"%output_file%"
echo Files (Full Paths):>>"%output_file%"
for /r %%F in (*) do (
    :: Skip the output file, the batch file itself, and tf_test.pem
    if /i not "%%F"=="%~f0" if /i not "%%F"=="%cd%\%output_file%" if /i not "%%~nxF"=="tf_test.pem" (
        :: Check if the file path contains .git or .terraform
        set "filepath=%%F"
        set "filepath=!filepath:\.GIT\=.git\!"
        set "filepath=!filepath:\.TERRAFORM\=.terraform\!"
        echo !filepath! | findstr /i /c:".git\\" /c:".terraform\\" >nul
        if !errorlevel! neq 0 (
            echo %%F>>"%output_file%"
        )
    )
)

echo.>>"%output_file%"
echo Done! Directory structure saved to: %output_file%
pause