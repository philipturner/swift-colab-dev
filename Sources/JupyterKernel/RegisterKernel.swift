import Foundation
import PythonKit

fileprivate let ipykernel_launcher = Python.import("ipykernel_launcher")

@_cdecl("JupyterKernel_registerSwiftKernel")
public func JupyterKernel_registerSwiftKernel() {
  print("=== Registering Swift Jupyter kernel ===")
  
  let fm = FileManager.default
  let jupyterKernelFolder = "/opt/swift/packages/JupyterKernel"
  
  // TODO: remove `if __name__ == "__main__":` if it isn't necesssary
  // try calling dlopen on PythonKit in this script to eliminate need for patchelf
  // hard-code RTLD flags - better yet - insert them into the script using 
  // string substitution from this Swift file
  let pythonScript = """
  from ctypes import PyDLL
  from wurlitzer import sys_pipes
  
  if __name__ == "__main__":
    with sys_pipes():
      PyDLL("/opt/swift/lib/libJupyterKernel.so").JupyterKernel_createSwiftKernel()
  """
  
  let swift_kernelPath = "\(jupyterKernelFolder)/swift_kernel.py"
  try? fm.removeItem(atPath: swift_kernelPath)
  fm.createFile(atPath: swift_kernelPath, contents: pythonScript.data(using: .utf8)!)
  
  // sys.argv = Bundle.main.executablePath
           
  let kernelPath = "\(jupyterKernelFolder)/kernel.json"
  try? fm.removeItem(atPath: kernelPath)
}
