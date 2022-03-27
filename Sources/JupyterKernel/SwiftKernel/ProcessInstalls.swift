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

fileprivate func sendStdout(_ message: String, insertNewLine: Bool = true) {
  let kernel = KernelContext.kernel
  kernel.send_response(kernel.iopub_socket, "stream", [
    "name": "stdout",
    "text": "\(message)\(insertNewLine ? "\n" : "")"
  ])
}

fileprivate var installedPackages: [String]! = nil
fileprivate var installedPackagesLocation: String! = nil
// To prevent to search for matching packages from becoming O(n^2)
fileprivate var installedPackagesMap: [String: Int]! = nil

fileprivate func readInstalledPackages() throws {
  installedPackages = []
  installedPackagesLocation = "\(installLocation)/index"
  installedPackagesMap = [:]
  
  if let packagesData = FileManager.default.contents(
     atPath: installedPackagesLocation) {
    let packagesString = String(data: packagesData, encoding: .utf8)!
    let lines = packagesString.split(separator: "\n").map(String.init)
    
    for i in 0..<lines.count {
      let spec = lines[i]
      installedPackages.append(spec)
      installedPackagesMap[spec] = i
    }
  }
}

fileprivate func writeInstalledPackages() throws {
  let packagesString = installedPackages.reduce("") {
    $0 + $1 + "\n"
  }
  let packagesData = packagesString.data(using: .utf8)!
  
  guard FileManager.default.createFile(
        atPath: installedPackagesLocation, contents: packagesData) else {
    throw Exception("""
      Could not write to file "\(installedPackagesLocation!)"
      """)
  }
}

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
  
  if installedPackages == nil || installedPackagesLocation != installLocation {
    try readInstalledPackages()
  }
  
  var packageID: Int
  if let index = installedPackagesMap[spec] {
    packageID = index
  } else {
    packageID = installedPackages.count
    installedPackages.append(spec)
    installedPackagesMap[spec] = packageID
  }
  
  // Summary of how this works:
  // - create a Swift package that depends all the modules that
  //   the user requested
  // - ask SwiftPM to build that package
  // - copy all the .swiftmodule and module.modulemap files that SwiftPM
  //   created to the Swift module search path
  // - dlopen the .so file that SwiftPM created
  
  // == Create the Swift package ==
  
  let packageName = "jupyterInstalledPackages\(packageID)"
  let packageNameQuoted = "\"\(packageName)\""
  
  let /*communist*/ manifest/*o*/ =
  """
  // swift-tools-version:4.2
  import PackageDescription
  let package = Package(
    name: \(packageNameQuoted),
    products: [
      .library(
        name: \(packageNameQuoted),
        type: .dynamic,
        targets: [\(packageNameQuoted)]
      )
    ],
    dependencies: [
      \(spec)
    ],
    targets: [
      .target(
        name: \(packageNameQuoted),
        dependencies: \(products),
        path: ".",
        sources: ["\(packageName).swift"]
      )
    ]
  )
  """
  
  let modulesHumanDescription = products.reduce("") {
    $0 + "    " + $1 + "\n"
  }
  sendStdout("""
    Installing package:
    \(spec)
    \(modulesHumanDescription)
    """, insertNewLine: false)
  sendStdout("""
    With SwiftPM flags:
    \(swiftPMFlags)
    """)
  sendStdout("""
    Working in:
    \(installLocation)
    """)
  
  let packagePath = "\(installLocation)/\(packageName)"
  try? fm.createDirectory(
    atPath: packagePath, withIntermediateDirectories: false)
  
  func createFile(name: String, contents: String) throws {
    let filePath = "\(packagePath)/\(name)"
    let data = contents.data(using: .utf8)!
    guard fm.createFile(atPath: filePath, contents: data) else {
      throw Exception("Could not write to file \"\(filePath)\".")
    }
  }
  
  try createFile(name: "Package.swift", contents: manifest)
  try createFile(name: "\(packageName).swift", contents: """
    // intentionally blank
    
    """)
  
  // == Ask SwiftPM to build the package ==
  
  let swiftPath = "/opt/swift/toolchain/usr/bin/swift"
  let buildProcess = subprocess.Popen([swiftPath, "build"] + swiftPMFlags,
                                      stdout: subprocess.PIPE,
                                      stderr: subprocess.STDOUT,
                                      cwd: packagePath)
  
  // Whenever the Swift package has been built at least one time before, it
  // outputs a massive, ugly JSON blob that cannot be suppressed. This
  // workaround filters that out.
  var currentlyInsideBrackets = false
  
  for buildOutputLine in Python.iter(
      buildProcess.stdout.readline, PythonBytes(Data())) {
    var str = String(buildOutputLine.decode("utf8"))!
    guard str.hasSuffix("\n") else {
      throw Exception("""
        A build output line from SwiftPM did not end with "\\n":
        \(str)
        """)
    }
    str.removeLast(1)
    
    if Int(str) != nil {
      continue 
    }
    if str.hasPrefix("{") {
      currentlyInsideBrackets = true
      continue
    }
    if str.hasPrefix("}") {
      currentlyInsideBrackets = false
      continue
    }
    if !currentlyInsideBrackets {
      sendStdout(str)
    }
  }
  
  let buildReturnCode = buildProcess.wait()
  if buildReturnCode != 0 {
    throw PackageInstallException("""
      Install Error: swift-build returned nonzero exit code \
      \(buildReturnCode).
      """)
  }
  
  try writeInstalledPackages()
}
