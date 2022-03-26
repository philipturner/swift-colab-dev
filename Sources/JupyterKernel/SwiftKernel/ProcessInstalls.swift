import Foundation
fileprivate let re = Python.import("re")
fileprivate let shlex = Python.import("shlex")

func processInstallDirective(
  line: String, isValidDirective: inout Bool
) throws {
  func attempt(_ regex: String, command: (String) throws -> Void) rethrows {
    let regexMatch = re.match(regex, line)
    if regexMatch != Python.None {
      let restOfLine = String(regexMatch.group(1))!
      try command(restOfLine)
      isValidDirective = true
    }
  }
  
  try attempt(###"""
    ^\s*%install-swiftpm-flags (.*)$
    """###, 
    command: processSwiftPMFlags)
  if isValidDirective { return }
}

fileprivate var swiftPMFlags: [String] = []

fileprivate func processSwiftPMFlags(restOfLine: String) throws {
  let flags = shlex[dynamicMember: "split"](restOfLine)
  swiftPMFlags += [String](flags)!
}
