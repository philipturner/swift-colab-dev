import Foundation
import PythonKit

fileprivate let ipykernel_launcher = Python.import("ipykernel_launcher")

@_cdecl("JupyterKernel_registerSwiftKernel")
public func JupyterKernel_registerSwiftKernel() {
  print("=== Registering Swift Jupyter kernel ===")
  
  let fm = FileManager.default
  
  // TODO: remove `if __name__ == "__main__":` if it isn't necesssary
  let pythonScript = """
  from ctypes import PyDLL
  from wurlitzer import sys_pipes
  
  if __name__ == "__main__":
    with sys_pipes():
      PyDLL("/opt/swift/lib/libJupyterKernel.so").JupyterKernel_createSwiftKernel()
  """
  
  // sys.argv = Bundle.main.executablePath
  
  let jupyterKernelFolder = "/opt/swift/packages/JupyterKernel"
  let swift_kernelPath = "\(jupyterKernelFolder)/swift_kernel.py"
  let kernelPath = "\(jupyterKernelFolder)/kernel.json"
  
  try? fm.removeItem(atPath: swift_kernelPath)
  try? fm.removeItem(atPath: kernelPath)
}
