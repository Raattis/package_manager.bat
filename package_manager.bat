: " In sh this syntax begins a multiline comment, whereas in batch it's a valid label that gets ignored.
@goto batch_bootstrap_builder "
if false; then */
#error Remember to insert '#if 0' into the compiler input pipe or skip the first 6 lines when compiling this file.
// Notepad++ run command: cmd /c 'cd /d $(CURRENT_DIRECTORY) &amp;&amp; $(FULL_CURRENT_PATH)'
#endif // GOTO_BOOTSTRAP_BUILDER

///////////////////////////////////////////////////////////////////////////////

#ifdef BOOTSTRAP_BUILDER
/*
fi # sh_bootstrap_builder

# Did you know that hashbang doesn't have to be on the first line of a file? Wild, right!
#!/usr/bin/env sh

compiler_executable=gcc
me=`basename "$0"`
no_ext=`echo "$me" | cut -d'.' -f1`
executable="${no_ext}.exe"
echo "#define PACKAGE_MANAGER
#line 1 \"$me\"
#if GOTO_BOOTSTRAP_BUILDER /*" | cat - $me | $compiler_executable -x c - -o $executable

compiler_exit_status=$?
if test $compiler_exit_status -ne 0; then echo "Failed to compile $me. Exit code: $compiler_exit_status"; exit $compiler_exit_status; fi

chmod +x $executable
./$executable

execution_exit_status=$?
if test $execution_exit_status -ne 0; then echo "$executable exited with status $execution_exit_status"; exit $execution_exit_status; fi

exit 0

///////////////////////////////////////////////////////////////////////////////

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
) | %compiler_executable% -xc - -run -bench -DPE_PRINT_SECTIONS
@exit ERRORLEVEL
*/
#endif // BOOTSTRAP_BUILDER

///////////////////////////////////////////////////////////////////////////////

#ifdef PACKAGE_MANAGER

#include <stdarg.h> // va_list, va_start, va_end
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h> // Used in dir_exists
#include <time.h>

#if defined(_WIN32) || defined(_WIN64)
#define PMBAT_WINDOWS 1
#else
#define PMBAT_WINDOWS 0
#endif

// rmdir, getcwd, chdir
#if PMBAT_WINDOWS
	// tcc gets these functions from somewhere
#else
	#include <unistd.h>
#endif

enum { TRACE=1, RECOMPILE_TCC_EVERY_TIME=0 };

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
		trace_printf("Allocating %d more bytes for tprintf.\n", TEMP_BUFFER_SIZE);

		temp_buffer_ptr = malloc(TEMP_BUFFER_SIZE);
		temp_buffer_head = 0;
		space_left = TEMP_BUFFER_SIZE;
	}

	char* result = temp_buffer_ptr + temp_buffer_head;

	int length = vsnprintf(result, space_left, fmt, args);

	if (length < 0)
	{
		if (space_left < TEMP_BUFFER_SIZE) // Possibly ran out of space
		{
			temp_buffer_head = TEMP_BUFFER_SIZE;
			return temp_printf_impl(fmt, args); // Try again with a new buffer
		}

		fprintf(stderr, "vsnprintf failed.\n");
		return "<FORMATTING ERROR>";
	}

	temp_buffer_head += length + 1;

	if (length > 0)
	{
		if (result[length] != 0)
			fprintf(stderr, "No null terminator?! After vsnprintf?!\n");
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
	trace_printf("Checking if '%s' exists ... ", filename);

	FILE* file = fopen(filename, "r");
	if (!file)
	{
		trace_printf("It does not.\n");
		return 0;
	}

	fclose(file);
	trace_printf("It does!\n");
	return 1;
}

int dir_exists(const char* path)
{
	trace_printf("Checking if '%s' path exists\n", path);

	struct stat directory_stat;
	return stat(path, &directory_stat) == 0 && S_ISDIR(directory_stat.st_mode);
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

#if PMBAT_WINDOWS
	char* command = tprintf("powershell -Command \"(New-Object System.Net.WebClient).DownloadFile('%s', '%s')\"", url, output);
#else
	char* command = tprintf("curl -o %s %s", output, url);
#endif
	return system(command);
}

int unzip_file(const char* zip_file, const char* destination, const char* subfolder)
{
	trace_printf("Unzipping '%s' from '%s' to '%s'\n", zip_file, subfolder, destination);

#if PMBAT_WINDOWS
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

#if PMBAT_WINDOWS
	char* command = tprintf("robocopy \"%s\" \"%s\" /E /MOVE", src, dst);
#else
	char* command = tprintf("mv -r \"%s\" \"%s\"", src, dst);
#endif
	return system(command);
}

int copy_file(const char* src, const char* dst)
{
	trace_printf("Copying file from '%s' to '%s'\n", src, dst);

#if PMBAT_WINDOWS
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
	const char* zip_file_name;
	const char* zip_internal_path_to_root;
	const char* download_path;
	int downloaded_zip_has_no_root_folder;
} Package_Args;

int download_and_unpack_package(Package_Args package_args)
{
	const char* main_file = package_args.main_file;
	const char* folder_name = package_args.folder_name;
	const char* zip_file_name = package_args.zip_file_name;
	const char* download_path = package_args.download_path;
	const char* main_file_path = tprintf("./%s/%s", folder_name, main_file);

	trace_printf("download_and_unpack_package('%s', '%s', '%s', '%s')\n", main_file, zip_file_name, folder_name, download_path);

	if (!file_exists(main_file_path))
	{
		if (dir_exists(folder_name))
		{
			fprintf(stderr, "WARNING: Path '%s' exists but doesn't contain '%s'\n", folder_name, main_file);
			//return 1;
		}

		char* zip_file_path = tprintf("./%s", zip_file_name);
		if (!file_exists(zip_file_path))
		{
			printf("Couldn't find './%s' or './%s' would you like me to download the program source code from '%s'? [Y/n] ", main_file_path, zip_file_path, download_path);
			if (!get_Yn_input())
				return 1;

			download_file(download_path, zip_file_path);
		}

		{
			char* unzip_dst_path =  tprintf("./%s", folder_name);
			char* unzip_src_path =  package_args.zip_internal_path_to_root ? tprintf("./%s", package_args.zip_internal_path_to_root) : ".";
			if (0 != unzip_file(zip_file_path, unzip_dst_path, unzip_src_path))
			{
				fprintf(stderr, "ERROR: Unzipping '%s' failed '%s' -> '%s'\n", zip_file_path, unzip_src_path, unzip_dst_path);
				return 1;
			}

			if (!dir_exists(folder_name))
			{
				fprintf(stderr, "ERROR: Unzipping '%s' to '%s' didn't create a '%s' directory\n", zip_file_path, unzip_dst_path, folder_name);
				return 1;
			}
		}

		if (!file_exists(main_file_path))
		{
			fprintf(stderr, "ERROR: '%s' didn't contain '%s'\n", zip_file_path, package_args.zip_internal_path_to_root ? main_file : main_file_path);
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
		fprintf(stderr, "Couldn't get working directory before executing '%s'.\n", command);
		return 1;
	}

	if (chdir(path) != 0) {
		fprintf(stderr, "ERROR: Couldn't move working directory from '%s' to '%s' before executing '%s'.\n", original_path, path, command);
		return 1;
	}

	int result = system(command);

	trace_printf("'%s' finished with return value: %d\n", command, result);
	if (result != 0)
	{
		fprintf(stderr, "'%s' returned %d.\n", command, result);
	}

	if (chdir(original_path) != 0) {
		fprintf(stderr, "ERROR: Couldn't return working directory to '%s' from '%s' after executing '%s'.\n", original_path, path, command);
		return 1;
	}

	return result;
}

time_t get_file_timestamp(const char *file_path)
{
	trace_printf("Fetching timestamp for '%s' ... ", file_path);

	struct stat file_stat;
	if (stat(file_path, &file_stat) == -1)
	{
		trace_printf("Unable to get file information for '%s'. Assuming it doesn't exist. Returning an old timestamp.\n", file_path);
		return (time_t)0;
	}

	time_t file_timestamp = file_stat.st_mtime;

	trace_printf("%ld\n", file_timestamp);
	return file_timestamp;
}

time_t get_newest_file_timestamp(const char *path)
{
	trace_printf("Newest file under '%s' ... ", path);

#ifdef _WIN32
	const char *command = tprintf("dir /b /s /o:-d \"%s\"", path);
#else
	const char *command = tprintf("find \"%s\" -type f -exec ls -lt {} +", path);
#endif

	FILE *fp = popen(command, "r");
	if (fp == NULL) {
		fprintf(stderr, "Failed to execute command: '%s'\n", command);
		exit(EXIT_FAILURE);
	}

	char result[1024];
	if (fgets(result, sizeof(result), fp) == NULL) {
		fprintf(stderr, "Failed to read command output:'%s'\n", command);
		exit(EXIT_FAILURE);
	}

	pclose(fp);

	if (result[strlen(result) - 1] == '\n')
	{
		result[strlen(result) - 1] = '\0';
	}

	return get_file_timestamp(result);
}

int build_tcc(const char* dst)
{
	if (!PMBAT_WINDOWS)
	{
		fprintf(stderr, "TCC building is only supported on Windows for now.\n");
		return 1;
	}

	/*
	Package_Args src_args =
	{
		.main_file = "tcc.c",
		.folder_name = "tcc_src",
		.zip_file_name = "release_0_9_27.zip",
		.zip_internal_path_to_root = "tinycc-release_0_9_27",
		.download_path = "https://github.com/TinyCC/tinycc/archive/refs/tags/release_0_9_27.zip",
	};
	*/

	/*
	*/
	Package_Args src_args =
	{
		.main_file = "tcc.c",
		.folder_name = "tcc_src",
		.zip_file_name = "mob.zip",
		.zip_internal_path_to_root = "tinycc-mob",
		.download_path = "https://github.com/TinyCC/tinycc/archive/refs/heads/mob.zip",
	};

	int return_value;

	if (0 != (return_value = download_and_unpack_package(src_args)))
		return return_value;

	const char* compiler_source = tprintf("./%s", src_args.folder_name);
	const char* compiler_executable = "./quine_bat/tcc.exe";
	if (!RECOMPILE_TCC_EVERY_TIME && get_newest_file_timestamp(compiler_source) < get_file_timestamp(compiler_executable))
	{
		trace_printf("Skipping tcc recompile. Contents of '%s' are older than '%s'.\n", compiler_source, compiler_executable);
	}
	else
	{
		if (!RECOMPILE_TCC_EVERY_TIME)
			trace_printf("Contents of '%s' are newer than '%s'.", compiler_source, compiler_executable);

		printf("Recompiling tcc...\n");

#if PMBAT_WINDOWS
		const char* path = tprintf(".\\%s\\win32", src_args.folder_name);
		const char* filename = "build-tcc.bat";
		{
			// Patch a bug in build-tcc.bat where it expects the folder to be git repo.
			const char* file_path = tprintf("%s\\%s", path, filename);
			FILE* build_tcc_bat = fopen(file_path, "rb+");
			if (!build_tcc_bat) {
				printf("Failed to open file. Err: %d\n", errno);
				return 1;
			}

			// It was a happy accident that these lines are the same length. I don't think this patching hack would work otherwise.
			const char needle[]      = "git.exe --version 2>nul";
			const char replacement[] = "git.exe rev-parse 2>nul";
			char line[16*1024];
			while (fgets(line, sizeof(line), build_tcc_bat))
			{
				if (0 == strncmp(line, needle, sizeof(needle) - 1))
				{
					fseek(build_tcc_bat, -strlen(line), SEEK_CUR);
					fwrite(replacement, sizeof(char), sizeof(replacement) - 1, build_tcc_bat);
					trace_printf("Replaced '%s' with '%s' in '%s'.\n", needle, replacement, file_path);
					break;
				}
			}

			fclose(build_tcc_bat);
		}

		const char* command = tprintf("build-tcc.bat -c \"..\\..\\tcc\\tcc.exe -DMEM_DEBUG=2\" -i \"..\\..\\%s\" -t 64 > nul", dst);
#else
		const char* path = package_args.folder_name;
		const char* command = tprintf("make");
#endif
		if (0 != (return_value = run_command(path, command)))
			return return_value;

		// Update tcc.exe timestamp to enable avoiding unnecessary recompilation
#if PMBAT_WINDOWS
		const char* dst_path = tprintf(".\\%s", dst);
		trace_printf("Copying '%s' on top of itself to force the timestamp to refresh.\n", dst_path);
		if (0 != (return_value = run_command(dst_path, "copy /b \"tcc.exe\"+\"NUL\" \"tcc.exe\" > NUL")))
			return return_value;
#else
		if (0 != (return_value = run_command(tprintf("./%s", dst), "touch \"tcc.exe\"")))
			return return_value;
#endif

		trace_printf("Successfully compiled TCC.\n");
	}

	return 0;
}

int build_quine_bat()
{
	Package_Args package_args =
	{
		.main_file = "quine.bat",
		.folder_name = "quine_bat",
		.zip_file_name = "quine_bat.zip",
		.zip_internal_path_to_root = "quine.bat-main",
		.download_path = "https://github.com/Raattis/quine.bat/archive/refs/heads/main.zip",
	};

	int return_value;

	if (0 != (return_value = download_and_unpack_package(package_args)))
		return return_value;

	if (!file_exists(tprintf("./%s/tcc.exe", package_args.folder_name))
		&& !dir_exists(tprintf("./%s/tcc", package_args.folder_name)))
	{
		// Copy the compiler zip file over to avoid unnecessary downloading

		const char* compiler_zip_name = "tcc-0.9.27-win64-bin.zip";
		if (file_exists(compiler_zip_name))
		{
			if (0 != (return_value = copy_file(compiler_zip_name, tprintf("./%s/%s", package_args.folder_name, compiler_zip_name))))
				return return_value;
		}
	}

	{
#if PMBAT_WINDOWS
		const char* command = package_args.main_file;
#else
		const char* command = tprintf("./%s", package_args.main_file);
#endif
		if (0 != (return_value = run_command(package_args.folder_name, command)))
			return return_value;
	}

	return 0;
}

int main(int argc, char** argv)
{
	int return_value;

#if PMBAT_WINDOWS
	if (0 != (return_value = build_tcc("quine_bat")))
	{
		fprintf(stderr, "WARNING: Couldn't build tcc from source. Falling back to prebuilt tcc for quine.bat\n");
	}
#endif

	if (0 != (return_value = build_quine_bat()))
		return return_value;

	if (0 != run_command("quine_bat", ".\\tcc.exe .\\libtcc_test.c -Ilibtcc -Llibtcc -Llib -llibtcc"))
	{
		fprintf(stderr, "Test compile failed.\n");
		return 1;
	}

	if (0 != run_command("quine_bat", ".\\libtcc_test.exe -Lgdi32 -Iinclude -Luser32 -Lkernel32"))
	{
		fprintf(stderr, "Test failed.\n");
		return 1;
	}

	return 0;
}

#endif // PACKAGE_MANAGER
