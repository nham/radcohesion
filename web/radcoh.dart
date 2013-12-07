import 'dart:html';
import 'dart:web_gl';

void main() {
  CanvasElement canvas = querySelector("#the-haps");
  RenderingContext gl = canvas.getContext3d();
  
  if(gl == null) {
    print("There's no 3d WebGL thingy. Whatever that is. Barf.");
    return;
  }
  
  gl.viewport(0, 0, canvas.width, canvas.height);
  
  Buffer triangleVertexPositionBuffer, squareVertexPositionBuffer;
  
  triangleVertexPositionBuffer = gl.createBuffer();
  
  gl.bindBuffer(ARRAY_BUFFER, triangleVertexPositionBuffer);
}
