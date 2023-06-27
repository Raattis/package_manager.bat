# package_manager.bat
A single file package manager

## Usage
Run `package_manager.bat` to download and run `quine.bat`.

Note that on Linux this requires `chmod +x package_manager.bat`. You can add a Makefile with
```make
all:
	chmod +x ./package_manager.bat
	./package_manager.bat
```
if you like but I find the presence of a Makefile to be more daunting than two short commands.

## Info & troubleshooting
On Windows, this automatically tries to download Tiny C Compiler. If the download fails due to permissions or something, it instructs you to download it manually.

On other platforms this uses `gcc`. Installing `gcc` is left as an excercise to the user.
