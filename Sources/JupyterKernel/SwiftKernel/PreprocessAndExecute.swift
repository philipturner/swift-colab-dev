import Foundation

fileprivate let re = Python.import("re")

func preprocessAndExecute(code: String) throws -> ExecutionResult {
  do {
    let preprocessed = try preprocess(code: code)
    return execute(code: preprocessed)
  } catch let e as PreprocessorException {
    return PreprocessorError(exception: e)
  }
}

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
    return try preprocess(line: lines[i], index: i)
  }
  return preprocessedLines.joined(separator: "\n")
}

// TODO: move %system and interface into %install commands here

fileprivate func preprocess(line: String, index lineIndex: Int) throws -> String {
  return line
}

// This is a dictionary to avoid having O(n^2) algorithmic complexity.
fileprivate var previouslyReadPaths: [String: Bool] = [:]

fileprivate func readInclude(restOfLine: String, lineIndex: Int) throws -> String {
  let nameMatch = re.match(###"""
  ^\s*"([^"]+)"\s*$
  """###, restOfLine)
  guard nameMatch != Python.None else {
    throw PreprocessorException(
            "Line \(line_index + 1): %include must be followed by a name in quotes")
  }
  
  let name = String(nameMatch.group(1))!
  let includePaths = ["/opt/swift/include", "/content"]
  var code: String? = nil
  var chosenPath = ""
  var rejectedAPath = false
  
  // Paths in "/content" should override paths in "/opt/swift/include".
  // Paths later in the list `includePaths` have higher priority.
  for includePath in includePaths {
    let path = includePath + "/" + name
    if previouslyReadPaths[path, default: false] { 
        rejectedAPath = true
        continue 
    }
    if let data = FileManager.default.contents(atPath: path) {
      code = String(data: data, encoding: .utf8)!
      chosenPath = path
    }
  }
  
  guard let code = code else {
    if rejectedAPath {
      return ""
    }
    
    // Reversing `includePaths` to show the highest-priority one first.
    throw PreprocessorException(
        "Line \(lineIndex + 1): Could not find \"\(name)\". Searched \(includePaths.reversed()).")
  }
  
  previouslyReadPaths[path] = true
  
  // TODO: Ensure I do not need an extra newline at the end of this.
  return """
  #sourceLocation(file: "\(chosenPath)", line: 1)
  \(code)
  \(getLocationDirective(lineIndex: lineIndex))
  """
}
