#include <stdio.h>
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
  debugger.SetAsync(false);
  
  if (swift_module_search_path_command) {
    debugger.HandleCommand(swift_module_search_path_command);
  }
  
  // LLDB will not crash when using script because this isn't macOS. However,
  // disabling scripting could decrease startup time if the debugger needs to
  // "load the Python scripting stuff".
  debugger.SetScriptLanguage(eScriptLanguageNone);
  
  const char *repl_swift = "/opt/swift/toolchain/usr/bin/repl_swift";
  target = debugger.CreateTargetWithFileAndArch(repl_swift, "");
  main_bp = target.BreakpointCreateByName(
    "repl_main", target.GetExecutable().GetFilename());
  
  // ASLR is forbidden on Docker, but it may not be forbidden on Colab. So, it
  // will not be disabled until there is proof it crashes Swift-Colab.
  process = target.LaunchSimple(NULL, repl_env, cwd);
  
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

int execute(const char *code, char **description) {
  SBValue result;
  auto errorType = result.GetError().GetType();
  
  if (errorType == eErrorTypeInvalid) {
    // TODO: set output
    return 0;
  } else if (errorType == eErrorTypeGeneric) {
    *result_description = NULL;
    return 1;
  } else {
    // TODO: set output
    return 2;
  }
}

int validation_test(const char *input)
{
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
