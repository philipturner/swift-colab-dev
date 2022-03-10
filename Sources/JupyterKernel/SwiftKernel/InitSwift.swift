import Foundation

fileprivate struct CEnvironment {
  var envp: OpaquePointer
  
  init(environment: [String: String]) {
    var envArray: [String] = []
    for (key, value) in environment {
      envArray.append("\(key)=\(value)")
    }
    typealias EnvPointerType = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    let envPointer = EnvPointerType.allocate(capacity: envArray.count + 1)
    envPointer[envArray.count] = nil
    for i in 0..<envArray.count {
      let originalStr = envArray[i]
      let strPointer = UnsafeMutablePointer<CChar>.allocate(capacity: originalStr.count + 1)
      _ = originalStr.withCString {
        memcpy(strPointer, $0, originalStr.count + 1)
      }
      envPointer[i] = strPointer
    }
    envp = OpaquePointer(envPointer)
  }
  
  func validate(environment: [String: String]) {
    var envArray: [String] = []
    for (key, value) in environment {
      envArray.append("\(key)=\(value)")
    }
    typealias ConstEnvPointerType = UnsafeMutablePointer<UnsafePointer<CChar>>
    let envPointer = ConstEnvPointerType(envp)
    var envArray2: [String] = []
    for i in 0..<envArray.count {
      envArray2.append(String(cString: envPointer[i]))
    }
    precondition(envArray == envArray2, "Did not match: \(envArray) and \(envArray2)")
    print("Did match: \(envArray) and \(envArray2)")
  }
}

func initSwift() throws {
  KernelContext.initialize_debugger(nil)
  let environment = ProcessInfo.processInfo.environment
  let cEnvironment = CEnvironment(environment: environment)
  cEnvironment.validate(environment: environment)
}
