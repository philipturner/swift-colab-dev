import Foundation

func doExecute(code: String) throws -> PythonObject? {
  if !KernelContext.debuggerInitialized {
    try initSwift()
    KernelContext.debuggerInitialized = true
  }
  
  // Start up a new thread to collect stdout.
  // TODO: attempt to use GCD or Swift Concurrency instead 
  // of spawning Python threads.
  let stdoutHandler = StdoutHandler()
  stdoutHandler.start()
  
  // Does KernelCommunicator even do anything? Is it just for graphs?
  
  // Execute the cell, handle unexpected exceptions, and make sure to
  // always clean up the stdout handler.
  var result: ExecutionResult
  do {
    defer {
      stdoutHandler.stop_event.set()
      stdoutHandler.join()
    }
    result = try executeCell(code: code)
  } catch {
    sendExceptionReport(whileDoing: "executeCell", error: error)
    throw error
  }
  
  var emptyResponse: PythonObject {
    return [
      "status": "ok",
      "execution_count": KernelContext.kernel.execution_count,
      "payload": [],
      "user_expressions": [:]
    ]
  }
  
  // Send values/errors and status to the client.
  if result is SuccessWithValue {
    let kernel = KernelContext.kernel
    kernel.send_response(kernel.iopub_socket, "execute_result", [
      "execution_count": kernel.execution_count,
      "data": [
          "text/plain": result.description.pythonObject
      ],
      "metadata": [:]
    ])
    return emptyResponse
  } else if result is SuccessWithoutValue {
    return emptyResponse
  } else if result is ExecutionResultError {

//       if stdout_handler.had_stdout:
//           # When there is stdout, it is a runtime error. Stdout, which we
//           # have already sent to the client, contains the error message
//           # (plus some other ugly traceback that we should eventually
//           # figure out how to suppress), so this block of code only needs
//           # to add a traceback.
//           traceback = []
//           traceback.append('Current stack trace:')
//           traceback += [
//               '\t%s' % frame
//               for frame in self._get_pretty_main_thread_stack_trace()
//           ]
    var traceback: [String]
    var isAlive: Int32 = 0
    _ = KernelContext.process_is_alive(&isAlive)
    
    if isAlive == 0 {
      traceback = ["Process killed"]
      sendIOPubErrorMessage(traceback: traceback)
      
      // Exit the kernel because there is no way to recover from a
      // killed process. The UI will tell the user that the kernel has
      // died and the UI will automatically restart the kernel.
      // We do the exit in a callback so that this execute request can
      // cleanly finish before the kernel exits.
      let loop = Python.import("ioloop").IOLoop.current()
      loop.add_timeout(Python.import("time").time() + 0.1, loop.stop)
    } else if Bool(stdoutHandler.had_stdout)! {
//     if true {
      // When there is stdout, it is a runtime error. Stdout, which we
      // have already sent to the client, contains the error message
      // (plus some other ugly traceback that we should eventually
      // figure out how to suppress), so this block of code only needs
      // to add a traceback.
      traceback = ["Current stack trace:"]
      
      for frame in KernelContext.kernel.main_thread {
        traceback.append("Hello World")
      }
      
      sendIOPubErrorMessage(traceback: traceback)      
    } else {
      // There is no stdout, so it must be a compile error. Simply return
      // the error without trying to get a stack trace.
      traceback = [result.description]
      sendIOPubErrorMessage(traceback: traceback)
    }
    
    return makeExecuteReplyErrorMessage(traceback: traceback)
  } else {
    fatalError("This should never happen.")
  }
}

fileprivate func setParentMessage() throws {
  // TODO: remove dependency on Python JSON once I figure
  // out what this parent message is
  let json = Python.import("json")
  let squash_dates = Python.import("jupyter_client").jsonutil.squash_dates
  let parentHeader = KernelContext.kernel._parent_header
  let jsonDumps = String(json.dumps(json.dumps(squash_dates(parentHeader))))!
  
  let result = execute(code: """
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

fileprivate func executeCell(code: String) throws -> ExecutionResult {
//   try setParentMessage()
  let result = try preprocessAndExecute(code: code, isCell: true)
  if result is ExecutionResultSuccess {
//     try afterSuccessfulExecution()
  }
  return result
}
