import Foundation

func doExecute(code: String) throws -> PythonObject? {
  if !KernelContext.debuggerInitialized {
    try initSwift()
    KernelContext.debuggerInitialized = true
  }
  return nil
}

fileprivate func makeExecuteReplyErrorMessage(traceback: [String]) -> PythonObject {
  return [
    "status": "error",
    "execution_count": KernelContext.kernel.execution_count,
    "ename": "",
    "evalue": "",
    "traceback": traceback
  ]
}

fileprivate func sendIOPubErrorMessage(traceback: [String]) {
  let kernel = KernelContext.kernel
  kernel.send_response(kernel.iopub_socket, "error", [
    "ename": "",
    "evalue": "",
    "traceback": traceback
  ])
}

fileprivate func sendExceptionReport(whileDoing: String, error: Error) {
  sendIOPubErrorMessage(traceback: [
    "Kernel is in a bad state. Try restarting the kernel.",
    "",
    "Exception in `\(whileDoing)`:",
    error.localizedDescription
  ])
}
