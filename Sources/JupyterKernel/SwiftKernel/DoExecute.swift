import Foundation

func doExecute(kernel: PythonObject, code: String) throws -> PythonObject? {
  if !KernelContext.debuggerInitialized {
    KernelContext.initialize_debugger("hello world 333")
    KernelContext.debuggerInitialized = true
  }
  return nil
}
