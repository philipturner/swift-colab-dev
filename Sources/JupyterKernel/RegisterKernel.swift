import Foundation
import PythonKit

fileprivate let ipykernel_launcher = Python.import("ipykernel_launcher")
fileprivate let KernelSpecManager = Python.import("jupyter_client").kernelspec.KernelSpecManager

@_cdecl("JupyterKernel_registerSwiftKernel")
public func JupyterKernel_registerSwiftKernel() {
  print("=== Registering Swift Jupyter kernel ===")
  
  let fm = FileManager.default
  let jupyterKernelFolder = "/opt/swift/packages/JupyterKernel"
  
  // Create Swift kernel script
  
  // TODO: remove `if __name__ == "__main__":` if it isn't necesssary
  let swiftScript = """
  #!/opt/swift/toolchain/usr/bin/swift
  import GLibc
  
  let libJupyterKernel = dlopen("/opt/swift/lib/libJupyterKernel.so", RTLD_LAZY | RTLD_GLOBAL)!
  let funcAddress = dlsym(libJupyterKernel, "JupyterKernel_createSwiftKernel")!
  
  let JupyterKernel_createSwiftKernel = unsafeBitCast(
    funcAddress, to: (@convention(c) () -> Void).self)
  JupyterKernel_createSwiftKernel()
  """
//   let pythonScript = """
//   #!/usr/bin/python3
//   from ctypes import PyDLL
//   from wurlitzer import sys_pipes
  
//   if __name__ == "__main__":
//     with sys_pipes():
//       PyDLL("/opt/swift/lib/libJupyterKernel.so").JupyterKernel_createSwiftKernel()
//   """
  
  let swiftKernelPath = "\(jupyterKernelFolder)/swift_kernel.swift"
  try? fm.removeItem(atPath: swiftKernelPath)
  fm.createFile(atPath: swiftKernelPath, contents: swiftScript.data(using: .utf8)!)
  
  // Create kernel spec
  
  let kernelSpec = """
  {
    "argv": [
      "\(Bundle.main.executablePath!)",
      "\(swiftKernelPath)",
      "-f".
      "{connection_file}"
    ],
    "display_name": "Swift",
    "language": "swift",
    "env": {
      
    }
  }
  """
  
  let kernelSpecPath = "\(jupyterKernelFolder)/kernel.json"
  try? fm.removeItem(atPath: kernelSpecPath)
  
  // Does this even do anything? Can I avoid it since I'm just overwriting the Python kernel?
  fm.createFile(atPath: kernelSpecPath, contents: kernelSpec.data(using: .utf8)!)
  // Do I need to add these file permissions?
  try! fm.setAttributes([.posixPermissions: NSNumber(0o755)], ofItemAtPath: kernelSpecPath)
  KernelSpecManager().install_kernel_spec(jupyterKernelFolder, "swift")
  
  // Overwrite Python kernel script
  
  let pythonKernelPath = String(ipykernel_launcher.__file__)!
  
  if !fm.contentsEqual(atPath: swiftKernelPath, andPath: pythonKernelPath) {
      try! fm.copyItem(atPath: swiftKernelPath, toPath: pythonKernelPath)
      
      print("""
      |
      ===----------------------------------------------------------------------------------------===
      === Swift-Colab overwrote the Python kernel with Swift, but Colab is still in Python mode. ===
      === To enter Swift mode, go to Runtime > Restart runtime (NOT Factory reset runtime).      ===
      ===----------------------------------------------------------------------------------------===
      |
      """)
  } else {
      print("=== Swift Jupyter kernel was already registered ===")
  }
}
