import Foundation
import PythonKit

fileprivate let ipykernel_launcher = Python.import("ipykernel_launcher")
fileprivate let KernelSpecManager = Python.import("jupyter_client").kernelspec.KernelSpecManager

@_cdecl("JupyterKernel_registerSwiftKernel")
public func JupyterKernel_registerSwiftKernel() {
  print("=== Registering Swift Jupyter kernel ===")
  
  let fm = FileManager.default
  let jupyterKernelFolder = "/opt/swift/packages/JupyterKernel"
  
  // Create kernel script
  
  // TODO: remove `if __name__ == "__main__":` if it isn't necesssary
  let pythonScript = """
  #!/usr/bin/python3
  from ctypes import PyDLL
  from wurlitzer import sys_pipes
  
  if __name__ == "__main__":
    with sys_pipes():
      PyDLL("/opt/swift/lib/libJupyterKernel.so").JupyterKernel_createSwiftKernel()
  """
  
  let swiftKernelPath = "\(jupyterKernelFolder)/swift_kernel.py"
  try? fm.removeItem(atPath: swiftKernelPath)
  fm.createFile(atPath: swiftKernelPath, contents: pythonScript.data(using: .utf8)!)
  
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
  try! fm.setAttributes([.posixPermissions: NSNumber(0o755)], ofItemAtPath: kernelSpecPath)
  KernelSpecManager().install_kernel_spec(jupyterKernelFolder, "swift")
}
