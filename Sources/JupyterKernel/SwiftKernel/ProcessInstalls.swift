import Foundation
fileprivate let re = Python.import("re")
fileprivate let shlex = Python.import("shlex")

func processInstallDirective(line: String, isValidDirective: inout Bool) throws {
  try attempt(
    regex: ###"""
    ^\s*%install-swiftpm-flags (.*)$
    """###, 
    command: processSwiftPMFlags, 
    line: line, 
    isValidDirective: &isValidDirective)
  if isValidDirective { return }
}

fileprivate func attempt(
  regex: String, 
  command: (String) throws -> Void,
  line: String, 
  isValidDirective: inout Bool
) rethrows {
  let regexMatch = re.match(regex, line)
  if regexMatch != Python.None {
    let restOfLine = String(regexMatch.group(1))!
    try command(restOfLine)
    isValidDirective = true
  }
}

fileprivate var swiftPMFlags: [String] = []

fileprivate func processSwiftPMFlags(restOfLine: String) throws {
  
}
