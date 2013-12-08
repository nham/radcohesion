library rad_cohesion;

import 'dart:math';
import 'dart:html';
import 'dart:web_gl';
import 'dart:typed_data';

// will replace this with vector_math package eventually. I just want to get something working now
part 'matrix4.dart';

// not sure yet
part 'gl_program.dart';

// declare the main canvas Element and RenderingContext
CanvasElement canvas;
RenderingContext gl;


void main() {
  mvMatrix = new Matrix4()..identity();
  canvas = querySelector("#the-haps");
  gl = canvas.getContext3d();
  
  if(gl == null) {
    print("There's no 3d WebGL thingy. Whatever that is. Barf.");
    return;
  }
  
  thingySetup();
  drawScene();
}

// the main buffer
Buffer innerVertexPosBuffer, outerVertexPosBuffer;

// not sure what this is
GlProgram program;


void thingySetup() {
  program = new GlProgram('''
      precision mediump float;

      void main(void) {
      gl_FragColor = vec4(0.8, 0.0, 1.0, 1.0);
      }
      ''','''
      attribute vec3 aVertexPosition;

      uniform mat4 uMVMatrix;
      uniform mat4 uPMatrix;

      void main(void) {
      gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
      }
      ''', ['aVertexPosition'], ['uMVMatrix', 'uPMatrix']);
  gl.useProgram(program.program);
  

  
  var x = cos(PI/3);
  var y = sin(PI/3);
  var h = 2 * y;
  var a = [0.0, 0.0, 0.0];
  var b = [2.0,  0.0, 0.0];
  var c = [1.0,  h, 0.0];
  var d = [1.0, 0.0, 0.0]; // between a & b
  var e = [2.0 - x, y, 0.0]; // between b & c
  var f = [x, y, 0.0]; // between c & a
  
  var outer = new List.from(a);
  var inner = new List.from(d);

  outer..addAll(b)
    ..addAll(b)..addAll(c)
    ..addAll(c)..addAll(a);
  
  inner..addAll(e)
    ..addAll(e)..addAll(f)
    ..addAll(f)..addAll(d);
  
  // I think there's a notion of a "current" array buffer, whatever an array buffer is
  // and all buffer operations to array buffers apply only to the current one?
  // so bindBuffer tells us that for all the buffer stuff that follows, we'll be using
  // this one (triangleVertexPositionBuffer)

  // I'm also not sure what STATIC_DRAW is and how it compares to other options!
  
  outerVertexPosBuffer = gl.createBuffer();
  gl.bindBuffer(ARRAY_BUFFER, outerVertexPosBuffer);
  gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(outer),
      STATIC_DRAW);
  
  
  innerVertexPosBuffer = gl.createBuffer();
  gl.bindBuffer(ARRAY_BUFFER, innerVertexPosBuffer);
  gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(inner),
      STATIC_DRAW);
  
  // Specify the color to clear with (black with 100% alpha) and then enable
  // depth testing.
  gl.clearColor(0.0, 0.1, 0.0, 1.0);
}



/// Perspective matrix
Matrix4 pMatrix;
/// Model-View matrix.
Matrix4 mvMatrix;
List<Matrix4> mvStack = new List<Matrix4>();

/**
 * Add a copy of the current Model-View matrix to the the stack for future
 * restoration.
 */
mvPushMatrix() => mvStack.add(new Matrix4.fromMatrix(mvMatrix));

/**
 * Pop the last matrix off the stack and set the Model View matrix.
 */
mvPopMatrix() => mvMatrix = mvStack.removeLast();


void drawScene() {
// set the GL viewport to the same size as the canvas element so there's no resizing
  gl.viewport(0, 0, canvas.width, canvas.height);
  gl.clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
  gl.enable(DEPTH_TEST);
  gl.disable(BLEND);
  
  var aspect = canvas.width / canvas.height;
  pMatrix = Matrix4.perspective(45.0, aspect, 0.1, 100.0);
  
  // First stash the current model view matrix before we start moving around.
  mvPushMatrix();

  mvMatrix.translate([-1.0, -1.0, -4.0]);

  // Here's that bindBuffer() again, as seen in the constructor
  gl.bindBuffer(ARRAY_BUFFER, outerVertexPosBuffer);
  // Set the vertex attribute to the size of each individual element (x,y,z)
  gl.vertexAttribPointer(program.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
  setMatrixUniforms();
  // Now draw 3 vertices
  gl.drawArrays(LINES, 0, 6);
  
  
  gl.bindBuffer(ARRAY_BUFFER, innerVertexPosBuffer);
  gl.vertexAttribPointer(program.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
  setMatrixUniforms();
  gl.drawArrays(LINES, 0, 6);
  
  
// Finally, reset the matrix back to what it was before we moved around.
  mvPopMatrix();
}

setMatrixUniforms() {
  gl.uniformMatrix4fv(program.uniforms['uPMatrix'], false, pMatrix.buf);
  gl.uniformMatrix4fv(program.uniforms['uMVMatrix'], false, mvMatrix.buf);
}
