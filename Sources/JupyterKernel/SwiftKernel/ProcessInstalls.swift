import Foundation
fileprivate let re = Python.import("re")
fileprivate let shlex = Python.import("shlex")
fileprivate let string = Python.import("string")
fileprivate let subprocess = Python.import("subprocess")

func processInstallDirective(
  line: String, lineIndex: Int, isValidDirective: inout Bool
) throws {
  func attempt(
    command: (String, Int) throws -> Void, _ regex: String
  ) rethrows {
    let regexMatch = re.match(regex, line)
    if regexMatch != Python.None {
      let restOfLine = String(regexMatch.group(1))!
      try command(restOfLine, lineIndex)
      isValidDirective = true
    }
  }
  
  attempt(command: processSwiftPMFlags, ###"""
    ^\s*%install-swiftpm-flags (.*)$
    """###)
  if isValidDirective { return }
  
  try attempt(command: processExtraIncludeCommand, ###"""
    ^\s*%install-extra-include-command (.*)$
    """###)
  if isValidDirective { return }
  
  try attempt(command: processInstallLocation, ###"""
    ^\s*%install-location (.*)$
    """###)
  if isValidDirective { return }
  
  try attempt(command: processInstall, ###"""
    ^\s*%install (.*)$
    """###)
  if isValidDirective { return }
}

// %install-swiftpm-flags

fileprivate var swiftPMFlags: [String] = []

fileprivate func processSwiftPMFlags(
  restOfLine: String, lineIndex: Int
) {
  let flags = shlex[dynamicMember: "split"](restOfLine)
  swiftPMFlags += [String](flags)!
}

// %install-extra-include-command

fileprivate func processExtraIncludeCommand(
  restOfLine: String, lineIndex: Int
) throws {
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
    if includeDir.prefix(2) != "-I" {
      KernelContext.kernel.log.warn("""
        Non "-I" output from \
        %install-extra-include-command: \(includeDir)
        """)
      continue
    }
    swiftPMFlags.append(includeDir)
  }
}

// %install-location

fileprivate var installLocation = "/opt/swift/build"

fileprivate func processInstallLocation(
  restOfLine: String, lineIndex: Int
) throws {
  installLocation = try substituteCwd(
    template: restOfLine, lineIndex: lineIndex)
}

fileprivate func substituteCwd(
  template: String, lineIndex: Int
) throws -> String {
  do {
    let output = try string.Template(template).substitute.throwing
      .dynamicallyCall(withArguments: [
        "cwd": FileManager.default.currentDirectoryPath
      ])
    return String(output)!
  } catch PythonError.exception(let error, let traceback) {
    let e = PythonError.exception(error, traceback: traceback)
    
    if Bool(Python.isinstance(error, Python.KeyError))! {
      throw PackageInstallException(
        "Line \(lineIndex + 1): Invalid template argument \(e)")
    } else if Bool(Python.isinstance(error, Python.ValueError))! {
      throw PackageInstallException(
        "Line \(lineIndex + 1): \(e)")
    } else {
      throw e
    }
  }
}

// %install

fileprivate func sendStdout(_ message: String) {
  let kernel = KernelContext.kernel
  kernel.send_response(kernel.iopub_socket, "stream", [
    "name": "stdout",
    "text": "\(message)\n"
  ])
}

fileprivate var installedPackages = {
  let fm = FileManager.default
  var output: [(spec: String, products: [String])] = []
  if let packagesData = fm.contents(atPath: "\(installLocation)/index") {
    let packagesString = String(data: packagesData, encoding: .utf8)!
    let lines = packagesString.split(
      separator: "\n", omittingEmptySubsequences: false)
    guard lines.count % 2 == 0 else {
      throw Exception("""
        The contents of "\(installLocation)/index" were malformatted:
        \(packagesString)
        """)
    }
    
    for i in 0..<lines.count / 2 {
      let spec = String(lines[i * 2])
      let productsString = lines[i * 2 + 1]
      let products = productsString.split(separator: " ").map(String.init)
      output.append((spec, products))
    }
  }
  return output
}()

fileprivate func processInstall(
  restOfLine: String, lineIndex: Int
) throws {
  let parsed = [String](shlex[dynamicMember: "split"](restOfLine))!
  if parsed.count < 2 {
    throw PackageInstallException(
      "Line \(lineIndex + 1): %install usage: SPEC PRODUCT [PRODUCT ...]")
  }
  
  // Expand template before writing to file
  let spec = try substituteCwd(template: parsed[0], lineIndex: lineIndex)
  let products = Array(parsed[1...])
  
  let fm = FileManager.default
  let linkPath = "/opt/swift/install_location"
  try? fm.removeItem(atPath: linkPath)
  try fm.createSymbolicLink(
    atPath: linkPath, withDestinationPath: installLocation)
  
//   var installedPackages: [(spec: String, products: [String])] = []
//   if let packagesData = fm.contents(atPath: "\(installLocation)/index") {
//     let packagesString = String(data: packagesData, encoding: .utf8)!
//     let lines = packagesString.split(
//       separator: "\n", omittingEmptySubsequences: false)
//     guard lines.count % 2 == 0 else {
//       throw Exception("""
//         The contents of "\(installLocation)/index" were malformatted:
//         \(packagesString)
//         """)
//     }
    
//     for i in 0..<lines.count / 2 {
//       let spec = String(lines[i * 2])
//       let productsString = lines[i * 2 + 1]
//       let products = productsString.split(separator: " ").map(String.init)
//       installedPackages.append((spec, products))
//     }
//   }
  
  // TODO: Remove when done debugging
  sendStdout(installedPackages.reduce("Previously installed packages:", {
    $0 + "\n" + String(describing: $1)
  }))
  
  // Not using a dictionary because this won't be O(n^2); there are a very small 
  // number of products per target. Also, it would mess with array indices.
}
