import Foundation

func afterSuccessfulExecution() {
  var serializedOutput: UnsafeMutablePointer<UInt64>?
  let error = KernelContext.after_successful_execution(&serializedOutput)
  if error != 0 {
    print("C++ part of `afterSuccessfulExecution` failed with error code \(error)")
    precondition(serializedOutput == nil)
  } else {
    print("C++ part of `afterSuccessfulExecution` succeeded.")
    precondition(serializedOutput != nil)
    free(serializedOutput)
  }
}
