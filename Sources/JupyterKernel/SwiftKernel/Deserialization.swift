import Foundation

func afterSuccessfulExecution() throws {
  var serializedOutput: UnsafeMutablePointer<UInt64>?
  let error = KernelContext.after_successful_execution(&serializedOutput)
  guard let serializedOutput = serializedOutput else {
    throw Exception(
      "C++ part of `afterSuccessfulExecution` failed with error code \(error).")
  }
   
  let output = try deserialize(executionOutput: serializedOutput)
  free(serializedOutput)
  
  let kernel = KernelContext.kernel
  let send_multipart = kernel.iopub_socket.send_multipart.throwing
  for message in output {
    try send_multipart.dynamicallyCall(withArguments: message.pythonObject)
  }
}

fileprivate func deserialize(
  executionOutput: UnsafeMutablePointer<UInt64>
) throws -> [[UnsafeBufferPointer]] {
  var stream = executionOutput
  let numJupyterMessages = Int(stream.pointee)
  stream += 1
  
  var jupyterMessages: [[Data]] = []
  jupyterMessages.reserveCapacity(numJupyterMessages)
  for _ in 0..<numJupyterMessages {
    let numParts = Int(stream.pointee)
    stream += 1
    
    var message: [Data] = []
    message.reserveCapacity(numParts)
    for _ in 0..<numParts {
      let numBytes = Int(stream.pointee)
      stream += 1
      
      let byteArray = Data(bytes: stream, count: numBytes)
      message.append(byteArray)
      stream += (numBytes + 7) / 8
    }
    jupyterMessages.append(message)
  }
  
  return jupyterMessages
}
