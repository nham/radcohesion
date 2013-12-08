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
Buffer triangleVertexPositionBuffer;

// not sure what this is
GlProgram program;


void thingySetup() {
  program = new GlProgram('''
      precision mediump float;

      void main(void) {
      gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
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
  
  triangleVertexPositionBuffer = gl.createBuffer();
  
  // I think there's a notion of a "current" array buffer, whatever an array buffer is
  // and all buffer operations to array buffers apply only to the current one?
  // so bindBuffer tells us that for all the buffer stuff that follows, we'll be using
  // this one (triangleVertexPositionBuffer)
  gl.bindBuffer(ARRAY_BUFFER, triangleVertexPositionBuffer);
  
  // we're maybe feeding in the vertices of an isosceles triangle here to the buffer.
  // I'm not exactly sure what "feeding in" means here.
  // I'm also not sure what STATIC_DRAW is and how it compares to other options!
  
  var x = 1 / tan(PI/3);
  var a = [0.0, 1.0, 0.0];
  var b = [-x,  0.0, 0.0];
  var c = [x,   0.0, 0.0];
  var d = [-1.0, -1.0, 0.0];
  var e = [0.0, -1.0, 0.0];
  var f = [1.0, -1.0, 0.0];
  
  var triforce = new List.from(a);
  triforce..addAll(b)
    ..addAll(b)..addAll(d)
    ..addAll(d)..addAll(e)
    ..addAll(e)..addAll(b)
    ..addAll(b)..addAll(c)
    ..addAll(c)..addAll(e)
    ..addAll(e)..addAll(f)
    ..addAll(f)..addAll(c)
    ..addAll(c)..addAll(a);
  
  gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(triforce),
      STATIC_DRAW);
  
  // Specify the color to clear with (black with 100% alpha) and then enable
  // depth testing.
  gl.clearColor(0.0, 0.0, 0.0, 1.0);
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

  mvMatrix.translate([-1.5, 0.0, -7.0]);

  // Here's that bindBuffer() again, as seen in the constructor
  gl.bindBuffer(ARRAY_BUFFER, triangleVertexPositionBuffer);
  // Set the vertex attribute to the size of each individual element (x,y,z)
  gl.vertexAttribPointer(program.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
  setMatrixUniforms();
  // Now draw 3 vertices
  gl.drawArrays(LINES, 0, 18);
  
// Finally, reset the matrix back to what it was before we moved around.
  mvPopMatrix();
}

setMatrixUniforms() {
  gl.uniformMatrix4fv(program.uniforms['uPMatrix'], false, pMatrix.buf);
  gl.uniformMatrix4fv(program.uniforms['uMVMatrix'], false, mvMatrix.buf);
}
