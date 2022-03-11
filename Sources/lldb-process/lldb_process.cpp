#include <stdio.h>
#include <string.h>
#include <LLDB/LLDB.h>

using namespace lldb;
SBDebugger debugger;
SBTarget target;
SBBreakpoint main_bp;
SBProcess process;
SBExpressionOptions expr_opts;
SBThread main_thread;

extern "C" {

// swift_module_search_path_command = 
// "settings append target.swift-module-search-paths \(swift_module_search_path)" 
int init_repl_process(const char *swift_module_search_path_command, 
                      const char **repl_env,
                      const char *cwd) {
  SBDebugger::Initialize();
  debugger = SBDebugger::Create();
  if (!debugger.IsValid())
    return 1;
  debugger.SetAsync(false);
  
  if (swift_module_search_path_command) {
    debugger.HandleCommand(swift_module_search_path_command);
  }
  
  // LLDB will not crash when using script because this isn't macOS. However,
  // disabling scripting could decrease startup time if the debugger needs to
  // "load the Python scripting stuff".
  debugger.SetScriptLanguage(eScriptLanguageNone);
  
  const char *repl_swift = "/opt/swift/toolchain/usr/bin/repl_swift";
  target = debugger.CreateTarget(repl_swift);
  if (!target.IsValid())
    return 2;
  
  main_bp = target.BreakpointCreateByName(
    "repl_main", target.GetExecutable().GetFilename());
  if (!main_bp.IsValid())
    return 3;
  
  // Turn off "disable ASLR". This feature uses the "personality" syscall
  // in a way that is forbidden by the default Docker security policy.
  // Although Colab is not Docker, ASLR still prevents the Swift stdlib
  // from loading.
  auto launch_info = target.GetLaunchInfo();
  auto launch_flags = launch_info.GetLaunchFlags();
  launch_info.SetLaunchFlags(launch_flags & ~eLaunchFlagDisableASLR);
  target.SetLaunchInfo(launch_info);
  
  process = target.LaunchSimple(NULL, repl_env, cwd);
  if (!process.IsValid())
    return 4;
  
  expr_opts = SBExpressionOptions();
  auto swift_language = SBLanguageRuntime::GetLanguageTypeFromString("swift");
  expr_opts.SetLanguage(swift_language);
  expr_opts.SetREPLMode(true);
  expr_opts.SetUnwindOnError(false);
  expr_opts.SetGenerateDebugInfo(true);
  
  // Sets an infinite timeout so that users can run aribtrarily long
  // computations.
  expr_opts.SetTimeoutInMicroSeconds(0);
  
  main_thread = process.GetThreadAtIndex(0);
  return 0;
}

// Caller must deallocate `description`.
int execute(const char *code, char **description) {
  auto result = target.EvaluateExpression(code, expr_opts);
  auto errorType = result.GetError().GetType();
  
  if (errorType == eErrorTypeGeneric) {
    *description = NULL;
  } else {
    SBStream stream;
    result.GetDescription(stream);
    const char *unowned_desc = stream.GetData();
    
    int desc_size = strlen(unowned_desc);
    char *owned_desc = (char *)malloc(desc_size + 1);
    memcpy(owned_desc, unowned_desc, desc_size + 1);
    *description = owned_desc;
  }
  
  if (errorType == eErrorTypeInvalid) {
    return 0;
  } else if (errorType == eErrorTypeGeneric) {
    return 1;
  } else {
    return 2;
  }
}

// Output is in a serialized format, like so:
// 1st level of recursion:
// - first 4 bytes (UInt32): header that says how many display messages
// 2nd level of recursion:
// - first 4 bytes (UInt32): header that says how many byte arrays
// 3rd level of recursion:
// - first 4 bytes (UInt32): header that says how long the byte array is
// - rest of line: data in the byte array, with allocated capacity rounded
// up to a multiple of 4 bytes
//
// Caller must deallocate `serialized_output`
int after_successful_execution(int **serialized_output) {
  const char *code = "JupyterKernel.communicator.triggerAfterSuccessfulExecution()";
  result = target.EvaluateExpression(code, expr_opts);
  auto errorType = result.GetError().GetType();
  
  if (errorType != eErrorTypeInvalid) {
    *serialized_output = NULL;
    return 1;
  }
  
  uint32_t num_display_messages = result.GetNumChildren();
  for (uint32_t i = 0; i < num_display_messages; ++i) {
    auto display_message = result.GetChildAtIndex(i);
    
    uint32_t num_byte_arrays = display_message.GetNumChildren();
    for (uint32_t j = 0; j < num_byte_arrays; ++j) {
      auto byte_array = display_message.GetChildAtIndex(j);
      
      // TODO: put read_byte_array into an external function
    }
  }
  
  *serialized_output = NULL;
  return 0;
}

int get_stdout(char *dst, int *buffer_size) {
  return int(process.GetSTDOUT(dst, size_t(buffer_size)));
}

int validation_test(const char *input) {
  lldb::SBDebugger::Initialize();
  auto debugger = lldb::SBDebugger::Create();
  
  auto expr_opts = lldb::SBExpressionOptions();
  auto swift_language = lldb::SBLanguageRuntime::GetLanguageTypeFromString("swift");
  expr_opts.SetLanguage(swift_language);
  expr_opts.SetREPLMode(true);
  expr_opts.SetUnwindOnError(false);
  expr_opts.SetGenerateDebugInfo(true);
  
  puts(input);
  return 123;
}

} // extern "C"
