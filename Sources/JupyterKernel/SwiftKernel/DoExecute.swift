import Foundation
fileprivate let squash_dates = Python.import("jupyter_client").jsonutil.squash_dates

func doExecute(code: String) throws -> PythonObject? {
  if !KernelContext.debuggerInitialized {
    try initSwift()
    KernelContext.debuggerInitialized = true
  }
  return nil
}

fileprivate func setParentMessage() throws {
  // TODO: remove dependency on Python JSON once I figure
  // out what this parent message is
  let parentHeader = KernelContext.kernel._parent_header
  let json = Python.import("json")
  let jsonDumps = String(json.dumps(json.dumps(squash_dates(parentHeader))))!
  
  let result = try execute(code: """
  JupyterKernel.communicator.updateParentMessage(
    to: KernelCommunicator.ParentMessage(json: \(jsonDumps)))
  """)
  if result is ExecutionResultError {
    throw Exception("Error setting parent message: \(result)")
  }
}

fileprivate func makeExecuteReplyErrorMessage(traceback: [String]) -> PythonObject {
  return [
    "status": "error",
    "execution_count": KernelContext.kernel.execution_count,
    "ename": "",
    "evalue": "",
    "traceback": traceback.pythonObject
  ]
}

fileprivate func sendIOPubErrorMessage(traceback: [String]) {
  let kernel = KernelContext.kernel
  kernel.send_response(kernel.iopub_socket, "error", [
    "ename": "",
    "evalue": "",
    "traceback": traceback.pythonObject
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
