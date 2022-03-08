import Foundation

fileprivate let signal = Python.import("signal")
fileprivate let ipykernel = Python.import("ipykernel")
fileprivate let ipykernel_launcher = Python.import("ipykernel_launcher")

@_cdecl("JupyterKernel_createSwiftKernel")
public func JupyterKernel_createSwiftKernel() {
  // TODO: remove this notice
  print("=== Creating Swift kernel ===")
  
  // Jupyter sends us SIGINT when the user requests execution interruption.
  // Here, we block all threads from receiving the SIGINT, so that we can
  // handle it in a specific handler thread.
  signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGINT])
  
  // TODO: launch kernel
  
  // Until there is a built-in alternative, switch back into Python mode on the next
  // runtime restart. This makes debugging a lot easier and decreases the chance my
  // main account will be kicked off of Colab for excessive restarts/downloads.
}
