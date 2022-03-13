import Foundation

func doExecute(code: String) throws -> PythonObject? {
  if !KernelContext.debuggerInitialized {
    try initSwift()
    KernelContext.debuggerInitialized = true
  }
  return nil
}

func makeExecuteReplyErrorMessage(traceback: [String]) -> PythonObject {
  return [
    "status": "error",
    "execution_count": KernelContext.kernel.execution_count,
    "ename": "",
    "evalue": "",
    "traceback": traceback
  ]
}
