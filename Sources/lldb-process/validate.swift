import Foundation
let fileName = "validate.swift"
print("=== begin \(fileName) ===")
print()

// For an unknown reason, only `liblldb.so` crashes when using a symbolic link at `/opt/swift/lib`
print("\(fileName): Debug checkpoint 1")
let lldb = dlopen("/opt/swift/toolchain/usr/lib/liblldb.so", RTLD_LAZY | RTLD_GLOBAL)
print("Should not be `nil`:", lldb as Any)

print("\(fileName): Debug checkpoint 2")
let lldb_process = dlopen("/opt/swift/lib/liblldb_process.so", RTLD_LAZY | RTLD_GLOBAL)
print("Should not be `nil`:", lldb_process as Any)

func loadSymbol<T>(name: String) -> T {
  let address = dlsym(lldb_process, name)
  print("Should not be `nil`:", address as Any)
  return unsafeBitCast(address, to: T.self)
}

let func1: @convention(c) (UnsafePointer<CChar>) -> Int32 =
  loadSymbol(name: "func1")

// For an unknown reason, it prints an error saying:
//   ModuleNotFoundError: No module named 'lldb'
// This error only happens on dev toolchains, maybe because the headers are for LLDB 10? 
// Regardless, the error seems to cause no harm.
print("Should see `success output` logged")
print(func1("success output"))
print("\(fileName): Debug checkpoint 3")

print()
print("=== end \(fileName) ===")
