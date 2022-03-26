import Foundation
fileprivate let re = Python.import("re")
fileprivate let shlex = Python.import("shlex")

func processInstallDirective(line: String, isValidDirective: inout Bool) throws {
  isValidDirective = true
  
  if try attempt(
    regex: ###"""
    ^\s*%install-swiftpm-flags (.*)$
    """###, 
    line: line, 
    command: processSwiftPMFlags
  ) {
    isValidDirective = true
    return
  }
}

fileprivate func attempt(
  regex: String, line: String, command: (String) throws -> Void
) rethrows -> Bool {
  let regexMatch = re.match(regex, line)
  if regexMatch != Python.None {
    let restOfLine = String(regexMatch.group(1))!
    try command(restOfLine)
    return true
  } else {
    return false
  }
}

fileprivate var swiftPMFlags: [String] = []

fileprivate func processSwiftPMFlags(restOfLine: String) throws {
  
}
