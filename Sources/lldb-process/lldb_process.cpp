#include <stdio.h>
#include <string.h>
#include <LLDB/LLDB.h>

bool debuggerInitialized = false;
lldb::SBDebugger debugger;

extern "C" {

// swift_module_search_path_command = 
// "settings append target.swift-module-search-paths \(swift_module_search_path)" 
int init_repl_process(const char *swift_module_search_path_command, 
                      const char **env,
                      const char *cwd) {
  lldb::SBDebugger::Initialize();
  debugger = lldb::SBDebugger::Create();
  debugger.SetAsync(false);
  
  if (swift_module_search_path_command) {
    debugger.HandleCommand(swift_module_search_path_command);
  }
  
  return 0;
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
