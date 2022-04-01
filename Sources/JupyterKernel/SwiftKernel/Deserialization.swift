import Foundation

func afterSuccessfulExecution() throws {
  var serializedOutput: UnsafeMutablePointer<UInt64>?
  let error = KernelContext.after_successful_execution(&serializedOutput)
  guard let serializedOutput = serializedOutput else {
    throw Exception(
      "C++ part of `afterSuccessfulExecution` failed with error code \(error).")
  }
  
  let output = try deserialize(executionOutput: serializedOutput)
  print("KernelCommunicator produced: \(output)")
  free(serializedOutput)
}

fileprivate func deserialize(executionOutput: UnsafeMutablePointer<UInt64>) throws -> [String] {
  var stream = executionOutput
  let numParts = Int(stream.pointee)
  stream += 1
  
  var parts: [String] = []
  parts.reserveCapacity(numJupyterMessages)
  for _ in 0..<numParts {
    let numBytes = Int(stream.pointee)
    stream += 1

    let byteArray = Data(
      bytesNoCopy: stream, count: numBytes, deallocator: .none)
    guard let message = String(data: byteArray, encoding: .utf8) else {
      throw Exception("Could not decode bytes: \(byteArray.map { $0 })")
    }
    parts.append(message)
    stream += (numBytes + 7) / 8
  }
  
  return jupyterMessages
}
