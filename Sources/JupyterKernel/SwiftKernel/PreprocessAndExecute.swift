import Foundation

func preprocessAndExecute(code: String) throws -> ExecutionResult {
  do {
    let preprocessed = try preprocess(code: code)
    return execute(code: preprocessed)
  } catch let e as PreprocessorException {
    return PreprocessorError(exception: e)
  }
}

// TODO: test that this function works
func execute(code: String) -> ExecutionResult {
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

fileprivate func preprocess(code: String) throws -> String {
  let lines = code.split(separator: "\n").map(String.init)
  let preprocessedLines = try lines.indices.map { i in
    return try preprocessLine(lines[i], index: i)
  }
  return preprocessedLines.joined(separator: "\n")
}

fileprivate func preprocessLine(_ line: String, index lineIndex: Int) throws -> String {
  return line
}
