#include <stdio.h>
#include <LLDB/LLDB.h>

bool debuggerInitialized = false;
lldb::SBDebugger debugger;

extern "C" {

int init_repl_process(const char *swift_module_search_path, 
                      const char **env,
                      const char *cwd) {
  lldb::SBDebugger::Initialize();
  debugger = lldb::SBDebugger::Create();
  if (swift_module_search_path) {
    puts(swift_module_search_path);
  }
  puts(env[0]);
  puts(env[1]);
  puts(cwd);
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
