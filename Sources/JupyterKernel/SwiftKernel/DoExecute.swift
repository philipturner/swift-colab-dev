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

func sendIOPubErrorMessage(traceback: [String]) {
  let kernel = KernelContext.kernel
  kernel.send_response(kernel.iopub_socket, "error", [
    "ename": "",
    "evalue": "",
    "traceback": traceback
  ])
}
