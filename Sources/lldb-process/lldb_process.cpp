#include <stdio.h>
#include <LLDB/LLDB.h>

bool debuggerInitialized = false;
lldb::SBDebugger debugger;

extern "C" {

// merge into init_repl_process eventually
void initialize_debugger(const char *swift_module_search_path, 
                         const char **env,
                         const char *cwd) {
  lldb::SBDebugger::Initialize();
  debugger = lldb::SBDebugger::Create();

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
