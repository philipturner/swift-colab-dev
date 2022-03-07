import Foundation
print("hello world 0")
let lldb = dlopen("/opt/swift/toolchain/usr/lib/liblldb.so", RTLD_LAZY | RTLD_GLOBAL)
print(lldb as Any)

print("hello world 1")
let lldb_process = dlopen("/opt/swift/lib/liblldb_process.so", RTLD_LAZY | RTLD_GLOBAL)
print(lldb_process as Any)

func loadSymbol<T>(name: String) -> T {
  let address = dlsym(lldb_process, name)
  print(address as Any)
  return unsafeBitCast(address, to: T.self)
}

let func1: @convention(c) (UnsafePointer<CChar>) -> Int32 =
  loadSymbol(name: "func1")

print(func1("success output"))
print("hello world 2")
