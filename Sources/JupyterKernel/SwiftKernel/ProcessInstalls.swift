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

typealias InstalledPackages = [(spec: String, products: [String])]
fileprivate var installedPackages: InstalledPackages! = nil
fileprivate var installedPackagesLocation: String! = nil
fileprivate var installedProductsDictionary: [String: Int]! = nil

fileprivate func readInstalledPackages() throws {
  installedPackages = []
  installedPackagesLocation = "\(installLocation)/index"
  installedProductsDictionary = [:]
  
  if let packagesData = FileManager.default.contents(
     atPath: installedPackagesLocation) {
    let packagesString = String(data: packagesData, encoding: .utf8)!
    var lines: [String]
    if packagesString == "" {
      lines = []
    } else {
      lines = packagesString.split(
        separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
    guard lines.count % 2 == 0 else {
      throw Exception("""
        The contents of "\(installLocation)/index" were malformatted. \
        There should be no unnecessary whitespace.
        Begin file:
        \(packagesString)
        End file:
        """)
    }
    
    for i in 0..<lines.count / 2 {
      let spec = lines[i * 2]
      let productsString = lines[i * 2 + 1]
      let products = productsString.split(separator: " ").map(String.init)
      installedPackages.append((spec, products))
      
      for product in products {
        if let index = installedProductsDictionary[product] {
          let conflictingSpec = installedPackages[index].spec
          throw Exception("""
            Could not decode "\(installedPackagesLocation!)". Both of these \
            packages produced "\(product)":
            \(conflictingSpec)
            \(spec)
            """)
        }
        installedProductsDictionary[product] = i
      }
    }
  }
}

fileprivate func writeInstalledPackages() throws {
  var packagesString = installedPackages.reduce("", {
    let productString = $1.products.reduce("", {
      $0 + " " + $1
    })
    return $0 + $1.spec + "\n" + productString + "\n"
  })
  if packagesString.hasSuffix("\n") {
    packagesString.removeLast(1)
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
  
//   sendStdout(installedPackages.reduce("Previously installed packages:", {
//     $0 + "\n" + String(describing: $1)
//   }))
//   sendStdout("Previously installed dictionary:\n\(installedProductsDictionary!)")
  
  var packageID: Int
  if let index = installedPackages.firstIndex(where: { $0.spec == spec }) {
    packageID = index
  } else {
    packageID = installedPackages.count
    installedPackages.append((spec, products))
  }
  
  // Just throw a soft warning if there's a duplicate product. SwiftPM will make
  // an error if there needs to be one. Also, this warning could help the user 
  // debug any error caused by duplicated products.
  for product in products {
    if let index = installedProductsDictionary[product], index != packageID {
      let conflictingSpec = installedPackages[index].spec
      sendStdout("""
        Warning: Both of these packages produced "\(product)":
        \(conflictingSpec)
        \(spec)
        """)
    }
    installedProductsDictionary[product] = packageID
  }
  
  let packageName = "jupyterInstalledPackages\(packageID)"
  let packageNameQuoted = "\"\(packageName)\""
  
  // Contents of the Swift package manifest
  let /*communist*/ manifest /*o*/ = // ;)
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
//   sendStdout("Manifest:\n\(manifest)")
  
//   sendStdout(installedPackages.reduce("Currently installed packages:", {
//     $0 + "\n" + String(describing: $1)
//   }))
//   sendStdout("Currently installed dictionary:\n\(installedProductsDictionary!)")
  
  var packageHumanDescription = 
    String(repeating: Character(" "), count: 4) + "\(spec)"
  for product in products {
    packageHumanDescription += "\n" +
      String(repeating: Character(" "), count: 8) + "\(product)"
  }
  
  sendStdout("""
    Installing package:
    \(packageHumanDescription)
    """)
  sendStdout("""
    With SwiftPM flags:
    \(swiftPMFlags)
    """)
  sendStdout("""
    Working in:
    \(installLocation)/modules
    """)
  
  try writeInstalledPackages()
}
