import Foundation

func afterSuccessfulExecution() throws {
  var serializedOutput: UnsafeMutablePointer<UInt64>?
  let error = KernelContext.after_successful_execution(&serializedOutput)
  guard let serializedOutput = serializedOutput else {
    throw Exception(
      "C++ part of `afterSuccessfulExecution` failed with error code \(error).")
  }
   
  let output = deserialize(executionOutput: serializedOutput)
  free(serializedOutput)
}

fileprivate func deserialize(executionOutput: UnsafeMutablePointer<UInt64>) -> [[String]] {
  var stream = executionOutput
  let numJupyterMessages = Int(stream.pointee)
  stream += 1
  
  var jupyterMessages: [[String]] = []
  jupyterMessages.reserveCapacity(numJupyterMessages)
  for _ in 0..<numJupyterMessages {
    let numDisplayMessages = Int(stream.pointee)
    stream += 1
    
    var displayMessages: [String] = []
    displayMessages.reserveCapacity(numDisplayMessages)
    for _ in 0..<numDisplayMessages {
      
    }
    jupyterMessages.append(displayMessages)
  }
  
  return []
}
