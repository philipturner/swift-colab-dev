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
  let streamSize = Int(stream.pointee)
  stream += 1
  
  var jupyterMessages: [[String]] = []
  jupyterMessages.reserveCapacity(streamSize)
  
  for _ in 0..<streamSize {
    
  }
  
  return []
}
