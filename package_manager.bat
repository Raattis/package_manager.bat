: " This is the beginning of a multiline comment in sh and a valid label in batch.
@goto batch_bootstrap_builder "
if false; then */
#error Remember to insert "#if 0" into the compiler input pipe or skip the first 6 lines when compiling this file.
// Notepad++ run command: cmd /c 'cd /d $(CURRENT_DIRECTORY) &amp;&amp; $(FULL_CURRENT_PATH)'
#endif // GOTO_BOOTSTRAP_BUILDER

///////////////////////////////////////////////////////////////////////////////

#ifdef BOOTSTRAP_BUILDER
/*
fi # sh_bootstrap_builder

#Did you know that hashbang doesn't have to be on the first line of a file? Wild, right! "
#!/bin/sh

compiler_executable=gcc
me=`basename "$0"`
no_ext=`echo "$me" | cut -d'.' -f1`
builder_executable="${no_ext}_builder.exe"
echo "#define PACKAGE_MANAGER
#line 1 \"$me\"
#if GOTO_BOOTSTRAP_BUILDER /*" | cat - $me | $compiler_executable -x c - -o $builder_executable

compiler_exit_status=$?
if test $compiler_exit_status -ne 0; then echo "Failed to compile $me. Exit code: $compiler_exit_status"; exit $compiler_exit_status; fi

chmod +x $builder_executable
./$builder_executable

execution_exit_status=$?
if test $execution_exit_status -ne 0; then echo "$builder_executable exited with status $execution_exit_status"; exit $execution_exit_status; fi

exit 0


:batch_bootstrap_builder
@echo off
set compiler_executable=.\tcc\tcc.exe
set compiler_zip_name=tcc-0.9.27-win64-bin.zip
set download_tcc=n
if not exist %compiler_executable% if not exist %compiler_zip_name% set /P download_tcc="Download Tiny C Compiler? Please, try to avoid unnecessary redownloading. [y/n] "

if not exist %compiler_executable% (
	if not exist %compiler_zip_name% (
		if %download_tcc% == y (
			powershell -Command "Invoke-WebRequest http://download.savannah.gnu.org/releases/tinycc/%compiler_zip_name% -OutFile %compiler_zip_name%"
			if exist %compiler_zip_name% (
				echo Download complete!
			) else (
				echo Failed to download %compiler_zip_name%
			)
		)

		if not exist %compiler_zip_name% (
			echo Download Tiny C Compiler manually from http://download.savannah.gnu.org/releases/tinycc/ and unzip it here.
			pause
			exit 1
		)
	)

	if not exist %compiler_executable% (
		echo Unzipping %compiler_zip_name%
		powershell Expand-Archive %compiler_zip_name% -DestinationPath .

		if not exist %compiler_executable% (
			echo Unzipping %compiler_zip_name% did not yield the expected %compiler_executable% file.
			echo Move the contents of the archive here manually so that %compiler_executable% exists.
			pause
			exit 1
		)
	)

	echo Tiny C Compiler Acquired!
) 

(
	echo #define PACKAGE_MANAGER
	echo #line 0 "%~n0%~x0"
	echo #if GOTO_BOOTSTRAP_BUILDER
	type %~n0%~x0
) | %compiler_executable% -xc - -run -bench
@exit ERRORLEVEL
*/
#endif // BOOTSTRAP_BUILDER

///////////////////////////////////////////////////////////////////////////////

#ifdef PACKAGE_MANAGER

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h> // For path_exists

enum { TRACE=0 };

enum { TEMP_BUFFER_SIZE=1024*1024 };
static char temp_buffer_first[TEMP_BUFFER_SIZE];
static char* temp_buffer_ptr = temp_buffer_first;
static int temp_buffer_head = 0;

#define trace_printf(...) do { if (TRACE) printf(__VA_ARGS__); } while(0)

static char* temp_printf_impl(const char* fmt, va_list args)
{
	int space_left = TEMP_BUFFER_SIZE - temp_buffer_head;

	if (space_left <= 0)
	{
		trace_printf("Allocating %d more bytes for tprintf.", TEMP_BUFFER_SIZE);

		temp_buffer_ptr = malloc(TEMP_BUFFER_SIZE);
		temp_buffer_head = 0;
	}

	char* result = temp_buffer_ptr + temp_buffer_head;

	int length = vsnprintf(result, space_left, fmt, args);

	if (length < 0)
	{
		fprintf(stderr, "vsnprintf failed.");
		return "<FORMATTING ERROR>";
	}

	temp_buffer_head += length + 1;

	if (length + 1 >= space_left) // Possibly ran out of space
	{
		if (length + 1 < TEMP_BUFFER_SIZE) // The buffer was already partially spent
		{
			return temp_printf_impl(fmt, args); // Try again with a new buffer
		}
	}
	
	if (length > 0)
	{
		if (result[length] != 0)
			fprintf(stderr, "No null terminator?! After vsnprintf?!");
	}

	return result;
}

char* tprintf(const char* fmt, ...)
{
	char* result;

	va_list args;
	va_start(args, fmt);
	result = temp_printf_impl(fmt, args);
	va_end(args);

	return result;
}

int file_exists(const char* filename)
{
	trace_printf("Checking if '%s' exists\n", filename);

	FILE* file = fopen(filename, "r");
	if (!file)
		return 0;

	fclose(file);
	return 1;
}

int path_exists(const char* path)
{
	trace_printf("Checking if '%s' path exists\n", path);

	struct stat directoryStat;
	return stat(path, &directoryStat) == 0 && S_ISDIR(directoryStat.st_mode);
}

int get_Yn_input()
{
	char answer[2];
	fgets(answer, sizeof(answer), stdin);
	char a = answer[0];
	return a == 'Y' || a == 'y' || a == '\0' || a == '\n';
}

int download_file(const char* url, const char* output)
{
	trace_printf("Downloading '%s' to '%s'\n", url, output);

#if defined(_WIN32) || defined(_WIN64)
	char* command = tprintf("powershell -Command \"(New-Object System.Net.WebClient).DownloadFile('%s', '%s')\"", url, output);
#else
	char* command = tprintf("curl -o %s %s", output, url);
#endif
	return system(command);
}

int unzip_file(const char* zip_file, const char* destination, const char* subfolder)
{
	trace_printf("Unzipping '%s' from '%s' to '%s'\n", zip_file, subfolder, destination);

#if defined(_WIN32) || defined(_WIN64)
    char* command = tprintf(
	"powershell -Command "
	"\""
	"Expand-Archive -Path '%s' -DestinationPath '%s/temp_unzip_hack' ; "
	"Get-ChildItem -Path '%s/temp_unzip_hack/%s' -Recurse -Exclude '*\\*' | Move-Item -Destination '%s' ; "
	"Remove-Item -Path '%s/temp_unzip_hack' -Recurse -Force"
	"\""
	, zip_file, destination
	, destination, subfolder, destination
	, destination);
#else
	char* command = tprintf("unzip %s '%s/*' -d %s", zip_file, subfolder, destination);
#endif
	return system(command);
}

int move_directory_contents(const char* src, const char* dst)
{
	trace_printf("Moving contents from '%s' to '%s'\n", src, dst);

#if defined(_WIN32) || defined(_WIN64)
	char* command = tprintf("robocopy %s %s /MOVE", src, dst);
#else
	char* command = tprintf("mv %s* %s", src, dst);
#endif
	return system(command);
}

int copy_file(const char* src, const char* dst)
{
	trace_printf("Copying file from '%s' to '%s'\n", src, dst);

#if defined(_WIN32) || defined(_WIN64)
	char* command = tprintf("copy /Y \"%s\" \"%s\"", src, dst);
#else
	char* command = tprintf("cp \"%s\" \"%s\"", src, dst);
#endif
	return system(command);
}

int remove_directory(const char* path)
{
	trace_printf("Removing directory '%s'\n", path);

	return rmdir(path);
}

typedef struct
{
	const char* main_file;
	const char* folder_name;
	const char* zip_internal_path_to_root;
	const char* download_path;
	int downloaded_zip_has_no_root_folder;
} Package_Args;

int download_and_unpack_package(Package_Args package_args)
{
	const char* main_file = package_args.main_file;
	const char* folder_name = package_args.folder_name;
	const char* download_path = package_args.download_path;
	const char* main_file_path = tprintf("./%s/%s", folder_name, main_file);

	trace_printf("download_and_unpack_package('%s', '%s', '%s')\n", package_args.main_file, package_args.folder_name, package_args.download_path);

	if (!file_exists(main_file_path))
	{
		if (path_exists(folder_name))
		{
			fprintf(stderr, "ERROR: Path '%s' exists but doesn't contain '%s'\n", folder_name, main_file);
			return 1;
		}

		const char* temp_zip_file = tprintf("%s.zip", folder_name);
		if (!file_exists(temp_zip_file))
		{
			printf("Couldn't find './%s' or './%s' would you like me to download the program source code from '%s'? [Y/n] ", main_file_path, temp_zip_file, download_path); 
			if (!get_Yn_input())
				return 1;

			download_file(download_path, temp_zip_file);
		}

		{
			char* unzip_dst_path =  tprintf("./%s", folder_name);
			char* unzip_src_path =  package_args.zip_internal_path_to_root ? tprintf("./%s", package_args.zip_internal_path_to_root) : ".";
			if (0 != unzip_file(temp_zip_file, unzip_dst_path, unzip_src_path))
			{
				fprintf(stderr, "ERROR: Unzipping '%s' failed '%s' -> '%s'\n", temp_zip_file, unzip_src_path, unzip_dst_path);
				return 1;
			}

			if (!path_exists(folder_name))
			{
				fprintf(stderr, "ERROR: Unzipping '%s' to '%s' didn't create a '%s' directory\n", temp_zip_file, unzip_dst_path, folder_name);
				return 1;
			}
		}

		if (!file_exists(main_file_path))
		{
			fprintf(stderr, "ERROR: '%s' didn't contain '%s'\n", temp_zip_file, package_args.zip_internal_path_to_root ? main_file : main_file_path);
			return 1;
		}
	}

	return 0;
}

int run_command(const char* path, const char* command)
{
	trace_printf("Running '%s' in '%s'\n", command, path);

	char original_path[4096];
	if (getcwd(original_path, sizeof(original_path)) == 0) {
		fprintf(stderr, "Couldn't get working directory before executing '%s'.", command);
		return 1;
	}

	if (chdir(path) != 0) {
		fprintf(stderr, "ERROR: Couldn't move working directory from '%s' to '%s' before executing '%s'.", original_path, path, command);
		return 1;
	}

	int result = system(command);

	trace_printf("'%s' finished with return value: %d\n", command, result);

	if (chdir(original_path) != 0) {
		fprintf(stderr, "ERROR: Couldn't return working directory to '%s' from '%s' after executing '%s'.", original_path, path, command);
		return 1;
	}

	return result;
}

int main(int argc, char** argv)
{
	Package_Args package_args = 
	{
		.main_file = "quine.bat",
		.folder_name = "quine_bat",
		.zip_internal_path_to_root = "quine.bat-main",
		.download_path = "https://github.com/Raattis/quine.bat/archive/refs/heads/main.zip",
	};

	int return_value;
	if (0 != (return_value = download_and_unpack_package(package_args)))
		return return_value;

	{
		// Copy the compiler zip file over to avoid double downloading

		const char* compiler_zip_name = "tcc-0.9.27-win64-bin.zip";
		if (file_exists(compiler_zip_name))
		{
			if (0 != (return_value = copy_file(compiler_zip_name, tprintf("./%s/%s", package_args.folder_name, compiler_zip_name))))
				return return_value;
		}
	}

	if (0 != (return_value = run_command(package_args.folder_name, package_args.main_file)))
		return return_value;

	return 0;
}

#endif // PACKAGE_MANAGER
