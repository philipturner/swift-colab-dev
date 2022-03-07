import Foundation
print("hello world 0")
// For an unknown reason, only `liblldb.so` crashes when using a symbolic link at `/opt/swift/lib`
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

// For an unknown reason, it prints an error saying:
//   ModuleNotFoundError: No module named 'lldb'
// This error only happens on dev toolchains, maybe because the headers are for LLDB 10? 
// Regardless, the error seems to cause no harm.
print(func1("success output"))
print("hello world 2")
