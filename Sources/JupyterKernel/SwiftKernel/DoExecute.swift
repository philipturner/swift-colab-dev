import Foundation

func doExecute(kernel: PythonObject, code: String) throws -> PythonObject? {
  if !KernelContext.debuggerInitialized {
    KernelContext.initialize_debugger()
    KernelContext.debuggerInitialized = true
  }
  return nil
}
