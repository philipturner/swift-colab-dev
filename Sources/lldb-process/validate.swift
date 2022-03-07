import Foundation

print("hello world")

// print(FileManager.default.contents(atPath: "/opt/swift/lib/libPythonKit.so") as Any)

let lldb_process = dlopen("/opt/swift/toolchain/usr/lib/lidlldb.so.10.0.0git", RTLD_LAZY | RTLD_GLOBAL)
// let lldb_process = dlopen("/opt/swift/packages/PythonKit/.build/release/libPythonKit.so", RTLD_LAZY | RTLD_GLOBAL)
// print(String(cString: dlerror()))
print(lldb_process)

// func loadSymbol<T>(name: String) -> T {
//   let address = dlsym(lldb_process, name)
//   print(address)
//   return unsafeBitCast(address, to: T.self)
// }

// let func1: @convention(c) (UnsafePointer<CChar>) -> Int32 =
//   loadSymbol(name: "func1")

// print(func1("success output"))
