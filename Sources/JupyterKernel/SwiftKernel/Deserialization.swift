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
  return []
}
