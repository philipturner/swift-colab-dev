import Foundation
fileprivate let re = Python.import("re")
fileprivate let shlex = Python.import("shlex")

func processInstallDirective(line: String, isValidDirective: inout Bool) throws {
  isValidDirective = true
  
  let swiftPMFlagsRegularExpression = ###"""
  ^\s*%system (.*)$
  """###
  let systemMatch = re.match(systemRegularExpression, line)
  guard systemMatch == Python.None else {
    let restOfLine = String(systemMatch.group(1))!
    executeSystemCommand(restOfLine: restOfLine)
    return ""
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
