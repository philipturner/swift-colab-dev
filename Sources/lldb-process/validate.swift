import Foundation

print("hello world")

// print(FileManager.default.contents(atPath: "/opt/swift/lib/libPythonKit.so") as Any)

let lldb_process = dlopen("/opt/swift/lib/libPythonKit.so", RTLD_LAZY | RTLD_GLOBAL)
print(dlerror())
print(lldb_process)

// func loadSymbol<T>(name: String) -> T {
//   let address = dlsym(lldb_process, name)
//   print(address)
//   return unsafeBitCast(address, to: T.self)
// }

// let func1: @convention(c) (UnsafePointer<CChar>) -> Int32 =
//   loadSymbol(name: "func1")

// print(func1("success output"))
