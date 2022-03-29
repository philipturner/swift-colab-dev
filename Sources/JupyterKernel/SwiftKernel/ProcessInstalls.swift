import Foundation
fileprivate let json = Python.import("json")
fileprivate let os = Python.import("os")
fileprivate let re = Python.import("re")
fileprivate let shlex = Python.import("shlex")
fileprivate let sqlite3 = Python.import("sqlite3")
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
  let result = subprocess.run(
    restOfLine,
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
// To avoid any name conflicts with unused cached modules, the
// "modules" directory resets before each Jupyter session. The
// build products are cached elsewhere, and just copied here.
fileprivate var modulesDirectoryInitialized = false

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
    throw PackageInstallException("""
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
  
  try writeInstalledPackages()
  
  // Summary of how this works:
  // - create a Swift package that depends all the modules that
  //   the user requested
  // - ask SwiftPM to build that package
  // - copy all the .swiftmodule and module.modulemap files that SwiftPM
  //   created to the Swift module search path
  // - dlopen the .so file that SwiftPM created
  
  // == Create the Swift package ==
  
  let packageName = "jupyterInstalledPackages\(packageID + 1)"
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
      throw PackageInstallException("Could not write to file \"\(filePath)\".")
    }
  }
  
  try createFile(name: "Package.swift", contents: manifest)
  try createFile(name: "\(packageName).swift", contents: """
    // intentionally blank
    
    """)
  
  // == Ask SwiftPM to build the package ==
  
  let swiftBuildPath = "/opt/swift/toolchain/usr/bin/swift-build"
  let buildProcess = subprocess.Popen(
    [swiftBuildPath] + swiftPMFlags,
    stdout: subprocess.PIPE,
    stderr: subprocess.STDOUT,
    cwd: packagePath)
  var currentlyInsideBrackets = false
  
  for buildOutputLine in Python.iter(
      buildProcess.stdout.readline, PythonBytes(Data())) {
    var str = String(buildOutputLine.decode("utf8"))!
    guard str.hasSuffix("\n") else {
      throw PackageInstallException("""
        A build output line from SwiftPM did not end with "\\n":
        \(str)
        """)
    }
    str.removeLast(1)
    
    // Whenever the Swift package has been built at least one time before, it
    // outputs a massive, ugly JSON blob that cannot be suppressed. This
    // workaround filters that out.
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
  
  let showBinPathResult = subprocess.run(
    [swiftBuildPath, "--show-bin-path"] + swiftPMFlags,
    stdout: subprocess.PIPE,
    stderr: subprocess.PIPE,
    cwd: packagePath)
  let binDir = String(showBinPathResult.stdout.decode("utf8").strip())!
  let libPath = "\(binDir)/lib\(packageName).so"
  
  // == Copy .swiftmodule and modulemap files to Swift module search path ==
  
  let moduleSearchPath = "\(installLocation)/modules"
  if !modulesDirectoryInitialized {
    try? fm.removeItem(atPath: moduleSearchPath)
    do {
      try fm.createDirectory(
        atPath: moduleSearchPath, withIntermediateDirectories: false)
    } catch {
      throw PackageInstallException("""
        Could not create "\(moduleSearchPath)".
        """)
    }
    modulesDirectoryInitialized = true
  }
  
  let buildDBPath = "\(binDir)/../build.db"
  guard fm.fileExists(atPath: buildDBPath) else {
    throw PackageInstallException("build.db is missing")
  }
  
  // Execute swift-package show-dependencies to get all dependencies' paths
  let swiftPackagePath = "/opt/swift/toolchain/usr/bin/swift-package"
  let dependenciesResult = subprocess.run(
    [swiftPackagePath, "show-dependencies", "--format", "json"],
    stdout: subprocess.PIPE,
    stderr: subprocess.PIPE,
    cwd: packagePath)
  let dependenciesJSON = dependenciesResult.stdout.decode("utf8")
  let dependenciesObj = json.loads(dependenciesJSON)
  
  func flattenDepsPaths(_ dep: PythonObject) -> [PythonObject] {
    var paths = [dep["path"]]
    if let dependencies = dep.checking["dependencies"] {
      for d in dependencies {
        paths += flattenDepsPaths(d)
      }
    }
    return paths
  }
  
  // Make list of paths where we expect .swiftmodule and .modulemap files of 
  // dependencies
  let dependenciesSet = Python.set(flattenDepsPaths(dependenciesObj))
  let dependenciesPaths = [String](Python.list(dependenciesSet))!
  
  func isValidDependency(_ path: String) -> Bool {
    for p in dependenciesPaths {
      if path.hasPrefix(p) {
        return true
      }
    }
    return false
  }
  
  // Query to get build files list from build.db
  // SUBSTR because string starts with "N" (why?)
  let SQL_FILES_SELECT = 
    "SELECT SUBSTR(key, 2) FROM 'key_names' WHERE key LIKE ?"
  
  // Connect to build.db
  let dbConnection = sqlite3.connect(buildDBPath)
  let cursor = dbConnection.cursor()
  
  // Process *.swiftmodule files
  cursor.execute(SQL_FILES_SELECT, ["%.swiftmodule"])
  let swiftModules = cursor.fetchall().map { row in String(row[0])! }
    .filter(isValidDependency)
  // Can't I just make a symbolic link instead?
  for path in swiftModules {
    let fileName = URL(fileURLWithPath: path).lastPathComponent
    let target = "\(moduleSearchPath)/\(fileName)"
    try? fm.removeItem(atPath: target)
    do {
      try fm.copyItem(atPath: path, toPath: target)
    } catch {
      throw PackageInstallException("""
        Could not copy "\(path)" to "\(target)".
        """)
    }
  }
  
  // Process modulemap files
  cursor.execute(SQL_FILES_SELECT, ["%/module.modulemap"])
  let modulemapPaths = cursor.fetchall().map { row in String(row[0])! }
    .filter(isValidDependency)
  for index in 0..<modulemapPaths.count {
    let filePath = modulemapPaths[index]
    // Create a separate directory for each modulemap file because the
    // ClangImporter requires that they are all named
    // "module.modulemap".
    // Use the module name to prevent two modulemaps for the same
    // dependency ending up in multiple directories after several
    // installations, causing the kernel to end up in a bad state.
    // Make all relative header paths in module.modulemap absolute
    // because we copy file to different location.
    
    var fileURL = URL(fileURLWithPath: filePath)
    let srcFileName = fileURL.lastPathComponent
    fileURL.deleteLastPathComponent()
    let srcFolder = fileURL.path
    
    var modulemapContents = 
      String(data: fm.contents(atPath: filePath)!, encoding: .utf8)!
    let lambda = PythonFunction { (m: PythonObject) in
      let relativePath = m.group(1)
      var absolutePath: PythonObject
      if Bool(os.path.isabs(relativePath))! {
        absolutePath = relativePath
      } else {
        absolutePath = os.path.abspath(
          srcFolder + "/" + String(relativePath)!)
      }
      return """
      header "\(absolutePath)"
      """
    }
    let headerRegularExpression = ###"""
    header\s+"(.*?)"
    """###
    modulemapContents = String(re.sub(
      headerRegularExpression, lambda, modulemapContents))!
    sendStdout("modulemap \(index):")
    sendStdout(modulemapContents)
    
    // In the original implementation, it would first search for the module name.
    // If available, it would name the folder "modulemap-\(moduleName)".
    // Otherwise, it would fall back to "modulemap-\(index)".
    //
    // Now, I would use "modulemap-\(packageID)-\(index)" instead because multiple
    // packages exist and "\(index)" would be a name collision across multiple
    // packages. But if that is going to work, why not skip searching for the 
    // module name and just use "modulemap-\(packageID)-\(index)"?
    //
    // Apparently, modulemaps are sometimes duplicated. For now, I will treat
    // this as if the mechanism described above is used.
    
    let moduleRegularExpression = ###"""
    module\s+([^\s]+)\s.*{
    """###
    let moduleMatch = re.match(moduleRegularExpression, modulemapContents)
    var moduleName: String
    if moduleMatch != Python.None {
      moduleName = String(moduleMatch.group(1))!
    } else {
      moduleName = "\(packageID + 1)-\(index + 1)"
    }
    
    let newFolderPath = "\(moduleSearchPath)/module-\(moduleName)"
    try? fm.createDirectory(
      atPath: newFolderPath, withIntermediateDirectories: false)
    
    let newFilePath = "\(newFolderPath)/module.modulemap"
    let modulemapData = modulemapContents.data(using: .utf8)!
    guard fm.createFile(atPath: newFilePath, contents: modulemapData) else {
      throw PackageInstallException("""
        Could not write to "\(newFilePath)".
        """)
    }
  }
  
}
