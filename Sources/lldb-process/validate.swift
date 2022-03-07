import Foundation

let lldb_process = dlopen("./lldb_process.so", RTLD_LAZY | RTLD_GLOBAL)

func loadSymbol<T>(name: String) -> T {
  let address = dlsym(lldb_process, name)
  return unsafeBitCast(address, to: T.self)
}

let func1: @convention(c) (UnsafePointer<CChar>) -> Int32 =
  loadSymbol(name: "func1")

print(func1("success output"))
