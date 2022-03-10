import Foundation

func doExecute(code: String) throws -> PythonObject? {
  if !KernelContext.debuggerInitialized {
    KernelContext.initialize_debugger(nil)
    KernelContext.debuggerInitialized = true
  }
  return nil
}
