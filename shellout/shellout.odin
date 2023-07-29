package shellout

// test of shelling out
// code suggested by ChatGPT prompt "how do you shell out 'pwd' in Odin and capture stdout and stderr?"
// corrections pt (ChatGPT got a lot of things wrong)

// As of my last update in September 2021, capturing both stdout (standard output) and stderr (standard error) from a shell command in Odin requires using the exec system call from the core package with a slight modification. The exec function can capture either stdout or stderr, but not both simultaneously. To capture both outputs, you need to run the command twice, once for stdout and once for stderr. Here's how you can do it:

import "core:os"
import "core:mem"
import "core:fmt"

// Main function
main :: proc() {
    // Command to execute
    command := "pwd"

    // Allocate buffers to capture stdout and stderr
    buffer_size := 256 // Adjust buffer size as needed
    stdout_buffer := mem.alloc(u8, buffer_size)
    //stderr_buffer := mem.alloc(u8, buffer_size)

    // Execute the command to capture stdout
    stdout_exit_code := os.exec(command, stdout_buffer, buffer_size)

    /* // Execute the command again to capture stderr */
    /* stderr_exit_code := os.exec(command, stderr_buffer, buffer_size, .{ .capture_stderr = true }) */

    // Check if the command executed successfully and capture stdout
    if stdout_exit_code == 0 {
        // Print the captured stdout
        fmt.printf("stdout: %v\n", stdout_buffer)
    } else {
        fmt.printf("Error executing command (stdout exit code: %d)\n", stdout_exit_code)
    }

    /* // Check if the command executed successfully and capture stderr */
    /* if stderr_exit_code == 0 { */
    /*     // Print the captured stderr */
    /*     printf("stderr: %.*s\n", cast(i32)str_len(stderr_buffer), stderr_buffer) */
    /* } else { */
    /*     printf("Error executing command (stderr exit code: %d)\n", stderr_exit_code) */
    /* } */
}

// In this example, we execute the pwd command twice using the exec system call. The first time, we pass stdout_buffer to capture the standard output, and the second time, we pass stderr_buffer to capture the standard error.

// After executing each command, we check the exit code (stdout_exit_code and stderr_exit_code) to determine if the command ran successfully. If it did, we print the captured output using printf.

// Please note that this approach might result in slight differences in the output since the pwd command could potentially have different results for stdout and stderr. Also, make sure to adjust the buffer size (buffer_size) as needed to accommodate the expected length of output from your command. The example provided above should give you a general idea of how to capture both stdout and stderr in Odin. As always, refer to the official documentation or Odin community resources for the most up-to-date information.
