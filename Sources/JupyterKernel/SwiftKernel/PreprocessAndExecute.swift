import Foundation

fileprivate func preprocessLine(index lineIndex: Int, line: String) throws -> String {
  return line
}

// TODO: test that this function works
fileprivate func execute(code: String) throws -> ExecutionResult {
  var descriptionPtr: UnsafeMutablePointer<CChar>?
  let err = KernelContext.execute(code, &descriptionPtr)
  
  var description: String?
  if let descriptionPtr = descriptionPtr {
    description = String(cString: descriptionPtr)
    free(descriptionPtr)
  }
  
  if err == 0 {
    return SuccessWithValue(description: description!)
  } else if err == 1 {
    return SuccessWithoutValue()
  } else {
    return SwiftError(description: description!)
  }
}
