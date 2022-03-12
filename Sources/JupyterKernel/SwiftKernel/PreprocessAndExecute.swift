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
func execute(code: String, lineIndex: Int? = -1) -> ExecutionResult {
  let locationDirective = getLocationDirective(lineIndex: lineIndex)
  let codeWithLocationDirective = locationDirective + "\n" + code
  
  var descriptionPtr: UnsafeMutablePointer<CChar>?
  let error = KernelContext.execute(codeWithLocationDirective, &descriptionPtr)
  
  var description: String?
  if let descriptionPtr = descriptionPtr {
    description = String(cString: descriptionPtr)
    free(descriptionPtr)
  }
  
  if error == 0 {
    return SuccessWithValue(description: description!)
  } else if error == 1 {
    return SuccessWithoutValue()
  } else {
    return SwiftError(description: description!)
  }
}

// Location directive for the current cell
//
// This adds one to `lineIndex` before creating the string.
// This does not include the newline that should come after the directive.
fileprivate func getLocationDirective(lineIndex: Int) -> String {
  let executionCount = Int(KernelContext.kernel.execution_count)!
  return """
  #sourceLocation(file: "<Cell \(executionCount)>", line: \(lineIndex + 1))
  """
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
