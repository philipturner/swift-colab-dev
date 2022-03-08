import Foundation
import PythonKit

fileprivate let ipykernel_launcher = Python.import("ipykernel_launcher")

@_cdecl("JupyterKernel_registerSwiftKernel")
public func JupyterKernel_registerSwiftKernel() {
  print("=== Registering Swift Jupyter kernel ===")
  
  let fm = FileManager.default
  let jupyterKernelFolder = "/opt/swift/packages/JupyterKernel"
  
  // TODO: remove `if __name__ == "__main__":` if it isn't necesssary
  let pythonScript = """
  from ctypes import PyDLL
  from wurlitzer import sys_pipes
  
  if __name__ == "__main__":
    with sys_pipes():
      PyDLL("/opt/swift/lib/libJupyterKernel.so").JupyterKernel_createSwiftKernel()
  """
  
  let swiftKernelPath = "\(jupyterKernelFolder)/swift_kernel.py"
  try? fm.removeItem(atPath: swiftKernelPath)
  fm.createFile(atPath: swiftKernelPath, contents: pythonScript.data(using: .utf8)!)
  
  // sys.argv = Bundle.main.executablePath
  
  let kernel_json
           
  let kernelSpecPath = "\(jupyterKernelFolder)/kernel.json"
  try? fm.removeItem(atPath: kernelSpecPath)
}
