import Foundation
import PythonKit

@_cdecl("JupyterKernel_registerSwiftKernel")
public func JupyterKernel_registerSwiftKernel() {
  print("=== Registering Swift Jupyter kernel ===")
  
  let pythonScript = """
  from ctypes import *
  from wurlitzer import sys_pipes
  
  with sys_pipes():
    PyDLL("/opt/swift/lib/libJupyterKernel.so").JupyterKernel_createSwiftKernel()
  """
}
