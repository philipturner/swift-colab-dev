import Foundation
fileprivate let re = Python.import("re")
fileprivate let shlex = Python.import("shlex")
fileprivate let string = Python.import("string")
fileprivate let subprocess = Python.import("subprocess")

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
  
  attempt(###"""
    ^\s*%install-swiftpm-flags (.*)$
    """###, 
    command: processSwiftPMFlags)
  if isValidDirective { return }
  
  try attempt(###"""
    ^\s*%install-extra-include-command (.*)$
    """###, 
    command: processExtraIncludeCommand)
  if isValidDirective { return }
}

fileprivate var swiftPMFlags: [String] = []

fileprivate func processSwiftPMFlags(restOfLine: String) {
  let flags = shlex[dynamicMember: "split"](restOfLine)
  swiftPMFlags += [String](flags)!
  printSwiftPMFlags()
}

fileprivate func printSwiftPMFlags() {
  let kernel = KernelContext.kernel
  kernel.send_response(kernel.iopub_socket, "stream", [
    "name": "stdout",
    "text": "\(swiftPMFlags.pythonObject)\n"
  ])
}

fileprivate func processExtraIncludeCommand(restOfLine: String) throws {
  let result = subprocess.run(restOfLine,
                              stdout: subprocess.PIPE,
                              stderr: subprocess.PIPE,
                              shell: true)
  if result.returncode != 0 {
    throw PackageInstallException("""
      %install-extra-include-command returned nonzero \
      exit code: \(result.returncode)
      Stdout: \(result.stdout.decode("utf8"))
      Stderr: \(result.stderr.decode("utf8"))
      """)
  }
  
  let includeDirs = shlex[dynamicMember: "split"](result.stdout.decode("utf8"))
  for includeDir in [String](includeDirs)! {
    if includeDir[0..<2] != "-I" {
      KernelContext.kernel.log.warn("""
        Non "-I" output from \
        %install-extra-include-command: \(includeDir)
        """)
      continue
    }
    swiftPMFlags.append(includeDir)
  }
  printSwiftPMFlags()
}
